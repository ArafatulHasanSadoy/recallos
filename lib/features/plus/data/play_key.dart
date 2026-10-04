/// RecallOS's licence key from Google Play, which every purchase receipt is
/// checked against.
///
/// From Play Console → RecallOS → Monetise with Play → Monetisation setup →
/// Licensing ("Base64-encoded RSA public key"), pasted 2026-10-04. It is a
/// *public* key, made to be shipped inside the app, so it belongs in the
/// repository; only Google holds the private half that signs receipts.
///
/// If it is ever emptied, Plus is not offered at all ([PlusController] treats
/// the store as unavailable): a purchase the build could not check would take
/// the money and never turn Plus on. `release_surface_test.dart` checks that
/// what is here really is an RSA public key.
const String kPlayLicenseKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtSoj+36eGbe7sNPVA3Iz'
    '3IeFzWQ3lTBVVDQkPVzHxUryrWWuFhnqbWEa/qKco/1es66HRYMRcJTe7y5dL/ja'
    'a20tVAIsDIvigZrVajK3iM8L8pr9MSYiaCE7daiVaw1Pop9kDEeN+6m0xfoTF8R+'
    'O1YDDuXsQTugOgNRiAGWB2aPDstYz7fIk1j1BlatmCCzKsh5dlk4Y17F7tc9kbrh'
    'sOtqBf9Hd0snd31yFkcUlgSG8psjfjVnz14n8DGYYTpzWwdP8Mybueuq+PckhY3V'
    '+TcLl8zFW/nC3YGo24pYnx1Ruyl7oXqPoEeSaJmkS0deNzTqq2kE0d5zKbCDYvMK'
    'BwIDAQAB';
