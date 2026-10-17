import MapKit
import SwiftUI

struct PhotoLocation {
  var coordinate: CLLocationCoordinate2D
  var country = ""
  var state = ""
  var city = ""
  var detail = ""

  init(coordinate: CLLocationCoordinate2D, placemark: CLPlacemark? = nil, name: String? = nil) {
    self.coordinate = coordinate
    country = placemark?.country ?? ""
    state = placemark?.administrativeArea ?? ""
    city = placemark?.locality ?? placemark?.subAdministrativeArea ?? ""
    detail = name ?? placemark?.name ?? ""
  }

  var metadata: [String: String] {
    [
      "GPS:GPSLatitude": String(abs(coordinate.latitude)),
      "GPS:GPSLatitudeRef": coordinate.latitude < 0 ? "S" : "N",
      "GPS:GPSLongitude": String(abs(coordinate.longitude)),
      "GPS:GPSLongitudeRef": coordinate.longitude < 0 ? "W" : "E",
      "XMP-exif:GPSLatitude": String(coordinate.latitude),
      "XMP-exif:GPSLongitude": String(coordinate.longitude),
      "XMP-photoshop:Country": country, "IPTC:Country-PrimaryLocationName": country,
      "XMP-photoshop:State": state, "IPTC:Province-State": state,
      "XMP-photoshop:City": city, "IPTC:City": city,
      "XMP-iptcCore:Location": detail, "IPTC:Sub-location": detail,
      // Altitude from the previous location would be misleading.
      "GPS:GPSAltitude": "", "GPS:GPSAltitudeRef": "",
      "XMP-exif:GPSAltitude": "", "XMP-exif:GPSAltitudeRef": "",
    ]
  }

  static func coordinate(from values: [String: String]) -> CLLocationCoordinate2D? {
    guard let lat = Double(values["GPS:GPSLatitude"] ?? ""),
      let lon = Double(values["GPS:GPSLongitude"] ?? "")
    else { return nil }
    let coordinate = CLLocationCoordinate2D(
      latitude: values["GPS:GPSLatitudeRef"] == "S" ? -abs(lat) : lat,
      longitude: values["GPS:GPSLongitudeRef"] == "W" ? -abs(lon) : lon)
    return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
  }
}

struct LocationPicker: View {
  let initial: [String: String]
  let onApply: (PhotoLocation) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var camera: MapCameraPosition = .automatic
  @State private var query = ""
  @State private var results: [MKMapItem] = []
  @State private var selection: PhotoLocation?
  @State private var notice = "搜索地点，或点击地图选点。应用后随图片保存。"
  @State private var searching = false
  @State private var locating = false
  @State private var searchTask: Task<Void, Never>?
  @State private var geocodeTask: Task<Void, Never>?
  @State private var geocoder = CLGeocoder()

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L("Apple 地图 · 图片位置")).font(.title3.weight(.medium))
      HStack {
        TextField(L("搜索城市、街道或地点"), text: $query).modifier(SoftField()).onSubmit { search() }
        Button(L("搜索")) { search() }.buttonStyle(SoftActionButtonStyle()).disabled(
          query.trimmingCharacters(in: .whitespaces).isEmpty)
        if searching || locating { ProgressView().controlSize(.small) }
      }
      HStack(alignment: .top, spacing: 12) {
        if !results.isEmpty {
          WarmScrollView {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                Button {
                  geocodeTask?.cancel()
                  geocoder.cancelGeocode()
                  locating = false
                  selection = PhotoLocation(
                    coordinate: item.placemark.coordinate, placemark: item.placemark,
                    name: item.name)
                  camera = .region(
                    MKCoordinateRegion(
                      center: item.placemark.coordinate, latitudinalMeters: 1500,
                      longitudinalMeters: 1500))
                  notice = "已选择地点，点击应用填入图片信息。"
                } label: {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? L("地点")).font(.body.weight(.medium))
                    Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                  }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.buttonStyle(QuietButtonStyle())
              }
            }
          }.frame(width: 210)
        }
        MapReader { proxy in
          Map(position: $camera) {
            if let selection {
              Marker(
                selection.detail.isEmpty ? L("选中位置") : selection.detail,
                coordinate: selection.coordinate)
            }
          }
          .mapControls {
            MapZoomStepper()
            MapCompass()
          }
          .onTapGesture { point in
            if let coordinate = proxy.convert(point, from: .local) { select(coordinate) }
          }
        }.clipShape(RoundedRectangle(cornerRadius: 12))
      }.frame(height: 360)
      if let selection {
        Text(
          [selection.country, selection.state, selection.city, selection.detail].filter {
            !$0.isEmpty
          }.joined(separator: " · "))
        Text(
          String(
            format: L("纬度 %.6f · 经度 %.6f"), selection.coordinate.latitude,
            selection.coordinate.longitude)
        )
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      }
      Text(L(notice)).font(.caption).foregroundStyle(.secondary)
      HStack {
        Text(L("地图与地点搜索需要联网")).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button(L("取消")) { dismiss() }.buttonStyle(SoftActionButtonStyle()).keyboardShortcut(
          .cancelAction)
        Button(L("应用位置")) {
          if let selection {
            onApply(selection)
            dismiss()
          }
        }.buttonStyle(SoftActionButtonStyle()).disabled(selection == nil || locating)
          .keyboardShortcut(.defaultAction)
      }
    }.padding(22).frame(width: 760).background(GlassBackground(tint: 0.18))
      .onAppear {
        if let coordinate = PhotoLocation.coordinate(from: initial) {
          var place = PhotoLocation(coordinate: coordinate)
          place.country = initial["XMP-photoshop:Country"] ?? ""
          place.state = initial["XMP-photoshop:State"] ?? ""
          place.city = initial["XMP-photoshop:City"] ?? ""
          place.detail = initial["XMP-iptcCore:Location"] ?? ""
          selection = place
          camera = .region(
            MKCoordinateRegion(
              center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))
        }
      }
      .onDisappear {
        searchTask?.cancel()
        geocodeTask?.cancel()
        geocoder.cancelGeocode()
      }
  }

  private func search() {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    searchTask?.cancel()
    searchTask = Task { @MainActor in
      searching = true
      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = text
      do {
        let response = try await MKLocalSearch(request: request).start()
        guard !Task.isCancelled else { return }
        results = response.mapItems
        notice = results.isEmpty ? "未找到地点，请换一个关键词。" : "选择搜索结果，或在地图上点击调整位置。"
        camera = .region(response.boundingRegion)
      } catch {
        guard !Task.isCancelled else { return }
        notice = "搜索失败，请检查网络后重试。"
      }
      searching = false
    }
  }

  private func select(_ coordinate: CLLocationCoordinate2D) {
    geocodeTask?.cancel()
    geocoder.cancelGeocode()
    selection = PhotoLocation(coordinate: coordinate)
    locating = true
    geocodeTask = Task { @MainActor in
      do {
        let places = try await geocoder.reverseGeocodeLocation(
          CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        guard !Task.isCancelled else { return }
        selection = PhotoLocation(coordinate: coordinate, placemark: places.first)
        notice = "已选择位置，点击应用填入图片信息。"
      } catch {
        guard !Task.isCancelled else { return }
        notice = "未获取到地址，仍可应用经纬度；旧地址将清空。"
      }
      locating = false
    }
  }
}
