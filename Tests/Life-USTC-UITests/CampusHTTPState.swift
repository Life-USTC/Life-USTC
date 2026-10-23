import Foundation

/// Canonical campus wire responses, with private preferences retained across reads.
final class CampusHTTPState {
    private var pinnedSlugs = ["academic"]
    private var busPreference: [String: Any] = ["preferredOriginCampusId": 1, "preferredDestinationCampusId": 2,
                                                "showDepartedTrips": false]

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        switch (request.method, request.path) {
        case ("GET", "/api/search"):
            guard request.query["scope"] == "catalog", request.query["limit"] == "25" else {
                return (400, ["error": "Expected public catalog search"])
            }
            return (200, ["query": request.query["q"] ?? "", "groups": [
                ["type": "sections", "items": [["id": "section:42", "title": "Calculus seminar", "description": "Fall 2026",
                                                  "code": "CALC-01", "href": "/catalog/sections/42"]]],
                ["type": "courses", "items": [["id": "course:1001", "title": "Calculus I", "description": "Course catalog",
                                                 "code": "CALC", "href": "/catalog/courses/1001"]]],
                ["type": "teachers", "items": [["id": "teacher:3", "title": "Calculus teaching team", "description": "Faculty",
                                                  "href": "/catalog/teachers/3"]]],
            ]])
        case ("GET", "/api/catalog/links"):
            return (200, ["links": [
                ["slug": "academic", "title": "Academic Portal", "description": "Courses and teaching services",
                 "url": "https://jw.ustc.edu.cn", "titlePinyin": "jiaowu", "descriptionPinyin": "kecheng",
                 "category": "academic", "icon": "book-open", "group": "study"],
                ["slug": "library", "title": "University Library", "description": "Books and study spaces",
                 "url": "https://lib.ustc.edu.cn", "titlePinyin": "tushuguan", "descriptionPinyin": "tushu",
                 "category": "academic", "icon": "book-open", "group": "study"],
            ]])
        case ("GET", "/api/workspace/link-pins"):
            return (200, pins)
        case ("POST", "/api/workspace/link-pins/batch"):
            guard let items = request.jsonBody["items"] as? [[String: String]], items.count == 1,
                  let slug = items[0]["slug"], ["academic", "library"].contains(slug),
                  let action = items[0]["action"], ["pin", "unpin"].contains(action) else {
                return (400, ["error": "Expected one explicit link pin action"])
            }
            pinnedSlugs.removeAll { $0 == slug }
            if action == "pin" { pinnedSlugs.append(slug) }
            return (200, pins)
        case ("GET", "/api/catalog/bus"):
            return (200, Self.timetable)
        case ("GET", "/api/catalog/bus/routes"):
            guard request.query["originCampusId"] == "1", request.query["destinationCampusId"] == "2" else {
                return (400, ["error": "Expected East to Gaoxin route"])
            }
            return (200, Self.routes)
        case ("GET", "/api/catalog/bus/next"):
            guard request.query["originCampusId"] == "1", request.query["destinationCampusId"] == "2" else {
                return (400, ["error": "Expected explicit boarding campuses"])
            }
            return (200, Self.next)
        case ("GET", "/api/workspace/bus-preferences"):
            return (200, ["preference": busPreference])
        case ("POST", "/api/workspace/bus-preferences"):
            guard let departed = request.jsonBody["showDepartedTrips"] as? Bool,
                  request.jsonBody["preferredOriginCampusId"] as? Int == 1,
                  request.jsonBody["preferredDestinationCampusId"] as? Int == 2 else {
                return (400, ["error": "Expected explicit saved bus choices"])
            }
            busPreference["showDepartedTrips"] = departed
            return (200, ["preference": busPreference])
        case ("GET", "/api/catalog/weather"):
            guard let key = request.query["locationKey"], ["ustc-main", "ustc-gaoxin"].contains(key) else {
                return (400, ["error": "Expected canonical weather location"])
            }
            return (200, weather(key))
        case ("GET", "/api/catalog/rooms/GT-999/map"):
            return (200, ["code": "GT-999", "building": NSNull(), "floor": NSNull(), "status": "unavailable",
                          "imageUrl": NSNull(), "sourceImageUrl": NSNull()])
        default: return nil
        }
    }

    private var pins: [String: Any] { ["pinnedSlugs": pinnedSlugs, "maxPinnedLinks": 4, "error": NSNull()] }

    private func weather(_ key: String) -> [String: Any] {
        ["location": ["key": key, "name": key == "ustc-main" ? "Main Campus" : "Gaoxin Campus", "adcode": "340100"],
         "fetchedAt": "2026-10-23T09:41:00+08:00", "providers": ["amap", "open-meteo"],
         "current": ["source": "amap", "observedAt": "2026-10-23T09:00:00+08:00", "temperature": key == "ustc-main" ? 22 : 21,
                     "feelsLike": 22, "humidity": 65, "windDirection": "East", "windSpeed": 2,
                     "condition": ["text": "Partly cloudy", "icon": "partly-cloudy"]],
         "hourly": (10...13).map { hour in ["at": "2026-10-23T\(hour):00:00+08:00", "temperature": 23,
                                            "condition": ["text": "Cloudy", "icon": "cloudy"],
                                            "precipitationProbability": 10, "precipitationAmount": 0] as [String: Any] },
         "daily": [["date": "2026-10-23", "temperatureHigh": 25, "temperatureLow": 17,
                     "condition": ["text": "Cloudy", "icon": "cloudy"]]],
         "alerts": [], "extensions": [:]]
    }

    private static let timetable: [String: Any] = try! JSONSerialization.jsonObject(with: Data(#"{"locale":"en-us","fetchedAt":"2026-10-23T09:00:00+08:00","version":{"id":1,"key":"native-parity-2026","title":"Autumn Shuttle Timetable","effectiveFrom":"2026-09-01T00:00:00+08:00","effectiveUntil":null,"importedAt":"2026-10-23T09:00:00+08:00","notice":null},"availableVersions":[{"id":1,"key":"native-parity-2026","title":"Autumn Shuttle Timetable","effectiveFrom":"2026-09-01T00:00:00+08:00","effectiveUntil":null,"importedAt":"2026-10-23T09:00:00+08:00","notice":null}],"campuses":[{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094}],"routes":[{"id":101,"nameCn":"East Campus → Gaoxin Campus","nameEn":"East Campus → Gaoxin Campus","descriptionPrimary":"Direct campus shuttle","descriptionSecondary":null,"stops":[{"stopOrder":0,"campus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264}},{"stopOrder":1,"campus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094}}]}],"trips":[{"id":201,"routeId":101,"dayType":"weekday","position":0,"departureTime":"23:00","departureMinutes":1380,"arrivalTime":"23:30","arrivalMinutes":1410,"stopTimes":[{"stopOrder":0,"campusId":1,"campusName":"East Campus","time":"23:00","minutesSinceMidnight":1380,"isPassThrough":false},{"stopOrder":1,"campusId":2,"campusName":"Gaoxin Campus","time":"23:30","minutesSinceMidnight":1410,"isPassThrough":false}]},{"id":202,"routeId":101,"dayType":"weekday","position":1,"departureTime":"23:30","departureMinutes":1410,"arrivalTime":"23:55","arrivalMinutes":1435,"stopTimes":[{"stopOrder":0,"campusId":1,"campusName":"East Campus","time":"23:30","minutesSinceMidnight":1410,"isPassThrough":false},{"stopOrder":1,"campusId":2,"campusName":"Gaoxin Campus","time":"23:55","minutesSinceMidnight":1435,"isPassThrough":false}]}],"preferences":null,"notice":null}"#.utf8)) as! [String: Any]

    private static let routes: [String: Any] = try! JSONSerialization.jsonObject(with: Data(#"{"originCampus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},"destinationCampus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094},"total":1,"routes":[{"id":101,"nameCn":"East Campus → Gaoxin Campus","nameEn":"East Campus → Gaoxin Campus","descriptionPrimary":"Direct campus shuttle","descriptionSecondary":null,"stops":[{"stopOrder":0,"campus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264}},{"stopOrder":1,"campus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094}}],"originCampus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},"destinationCampus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094},"stopCount":2,"weekdayTrips":2,"saturdayTrips":0,"sundayTrips":0}]}"#.utf8)) as! [String: Any]

    private static let next: [String: Any] = try! JSONSerialization.jsonObject(with: Data(#"{"originCampus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},"destinationCampus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094},"atTime":"2026-10-23T09:41:00+08:00","dayType":"weekday","totalRoutes":1,"departures":[{"tripId":201,"routeId":101,"route":{"id":101,"nameCn":"East Campus → Gaoxin Campus","nameEn":"East Campus → Gaoxin Campus","descriptionPrimary":"Direct campus shuttle","descriptionSecondary":null},"originCampus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},"destinationCampus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094},"departureTime":"23:00","arrivalTime":"23:30","departureEstimated":false,"arrivalEstimated":false,"minutesUntilDeparture":799,"dayType":"weekday","status":"upcoming"},{"tripId":202,"routeId":101,"route":{"id":101,"nameCn":"East Campus → Gaoxin Campus","nameEn":"East Campus → Gaoxin Campus","descriptionPrimary":"Direct campus shuttle","descriptionSecondary":null},"originCampus":{"id":1,"nameCn":"East Campus","nameEn":"East Campus","namePrimary":"East Campus","nameSecondary":null,"latitude":31.837,"longitude":117.264},"destinationCampus":{"id":2,"nameCn":"Gaoxin Campus","nameEn":"Gaoxin Campus","namePrimary":"Gaoxin Campus","nameSecondary":null,"latitude":31.839,"longitude":117.094},"departureTime":"23:30","arrivalTime":"23:55","departureEstimated":false,"arrivalEstimated":false,"minutesUntilDeparture":829,"dayType":"weekday","status":"upcoming"}],"nextAvailableDeparture":null,"message":null}"#.utf8)) as! [String: Any]
}
