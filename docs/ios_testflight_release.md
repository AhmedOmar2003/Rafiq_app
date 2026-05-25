# iOS TestFlight Link (Rafiq)

This project is prepared with Codemagic CI to generate iOS builds and publish them to TestFlight.

## 1) One-time setup in Apple

1. Create an app in App Store Connect.
2. Use bundle ID: `com.ahmedomar2003.rafiq`.
3. In App Store Connect, create an API key (Issuer ID, Key ID, and `.p8` key file).

## 2) One-time setup in Codemagic

1. Connect repository `AhmedOmar2003/Rafiq_Master` to Codemagic.
2. In Codemagic, open workflow `ios-testflight` from `codemagic.yaml`.
3. Add App Store Connect integration using your Apple API key (`.p8`, Issuer ID, Key ID).
4. Enable automatic code signing for this workflow.

## 3) Run release

1. Start workflow `ios-testflight`.
2. Wait for build and upload to finish.
3. Open App Store Connect -> TestFlight.
4. Add internal/external testers.
5. Copy and share your public TestFlight invitation link.

## Result

After first successful run, every new run can produce updated iOS builds for the same TestFlight link.
