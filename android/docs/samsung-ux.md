# Samsung phone and Fold layout

The layout follows the width of the app window, using the same breakpoints as Material window-size classes:

| Window width | Layout |
|---|---|
| under 600dp | Compact. One column, bottom navigation. A cover screen and a normal phone land here. |
| 600dp up to 839dp | Medium. Navigation rail, metrics in two columns. An unfolded Fold in portrait is usually here. |
| 840dp and wider | Expanded. Navigation rail, and the breakdown and the budget/forecast sit side by side. |

`paneLayoutForWidthDp` in `android/core` is the only decision. A width of 0 (the first frame, before the window is measured) stays compact so the UI does not flash a tablet layout. The code does not read `FoldingFeature`, a hinge angle, or a posture. Those signals are easy to invent and were not checked on a physical Galaxy Fold. When the user opens or closes the fold, Android reports a new window size, the activity is recreated, and the `ViewModel` keeps the open sample.

Other choices that matter on a Samsung phone:

- Edge-to-edge, with safe-drawing padding so the banner and the bottom bar clear the gesture area and the camera cutout.
- Touch targets are at least 48dp (buttons, the currency control, back).
- The sample banner is amber on near-black in both light and dark theme, and it is a heading, so it is not only a color.
- Budget status is a sentence (under the threshold, at the threshold, over budget) as well as a bar. The bar uses the error color when the sample is over budget, but the sentence is the accessible name of the state.
- The daily chart has a text summary (highest day, latest day, amounts). The canvas itself is one spoken node.
- Type is in `sp`. Compact width stacks the money cards in one column so a large font does not squeeze two headlines onto one row.
- Currency still follows the web: koruna uses Czech grouping, dollars use the US dollar format. The UI language is separate (Czech by default, English in `values-en`).
- No dynamic color. A wallpaper-driven palette would make the sample banner and the budget colors drift, and this build was not checked on One UI’s color implementation.
- System font, no bundled typeface and no network font.

Checked on an API 35 AOSP ATD emulator (Pixel 6 profile, 1080×2400). The signed-out screen, the Pro sample (overview, providers, budget and forecast), the Free sample’s missing-budget explanation, and a window resized to 2400×1600 were all present in the accessibility tree. At the wider size the destinations moved to a side rail. Headless gfxstream did not composite a framebuffer, so `screencap` stayed black and there are no pixel screenshots. This was not a physical Galaxy Fold, and the layout still does not read a hinge.
