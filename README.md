# swiftjor

My SwiftUI learning playground — a collection of small Xcode projects, each exploring a different concept or API.

## Projects

| Project | What it explores |
|---|---|
| `HelloWorld` | First SwiftUI app — `@State`, `Button`, `VStack`/`HStack`, modifiers |
| `welcomepage` | Layout practice — counter UI with SF Symbols and styling |
| `test` | `@State` arrays of custom models, sheets, `UserDefaults` persistence with `JSONEncoder` |
| `navproject` | `TabView` with `tabBarMinimizeBehavior`, `@AppStorage`, search role, sheet interception |
| `authflowApp` | Onboarding / auth flow — `NavigationStack`, multi-screen navigation |
| `cryptoApp` | Networking — `async/await` fetch, `ObservableObject` view model, API key handling |
| `weatherapp` | API consumption with a secrets decoder |
| `CamTest` | Camera + photo library — capture view, gallery grid, photo detail |

## Structure

Each subfolder is a standalone Xcode project (`<name>.xcodeproj`). Open the `.xcodeproj` in Xcode and run.

## Requirements

- Xcode (recent version)
- iOS simulator or device

## Notes

- `cryptoApp` and `weatherapp` use API keys stored in a local `Secrets`/`Secerts` file (not committed).
- Built by [@topeakintola](mailto:tope@robotostudio.com) while learning SwiftUI.
