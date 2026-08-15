/// The shape of the *frame* a saved card is drawn in.
///
/// ISO/IEC 7810 ID-1 — 85.60 × 53.98 mm, the credit-card proportion Google
/// Wallet and Apple Wallet use. Every tile and every card header is this shape,
/// which is what makes a library of them read as a wallet.
///
/// It deliberately says nothing about the images themselves. Real business
/// cards are not all one size — 90×50 mm is common in Bangladesh, 3.5×2 in in
/// the US, and slimmer formats are ordinary — so scaling a card to this ratio
/// stretches it visibly and makes the type look wrong. The frame is uniform;
/// the card inside it keeps whatever shape it really is.
const double cardAspectRatio = 1.586;
