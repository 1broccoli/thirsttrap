# ThirstTrap (Classic/TBC)

Mage trade helper using Ace3. Adds a Blizzard-styled secure button to the TradeFrame that, when clicked, places configured stacks of conjured water/food into trade slots — strictly manual, ToS-safe.

Features:
- Up to 6 stacks per trade
- Per-class amounts + BG/Arena override
- Whisper parsing (e.g., "2 stacks", "water only")
- Inventory scanning; icon shows highest available conjured item
- Minimap button: left opens config, right toggles auto
- Lifetime + daily statistics

## Install
Copy the `ThirstTrap` folder (and the `Ace3` folder already included in this workspace) into your WoW `Interface/AddOns`.

## Usage
- Trade someone and click the ThirstTrap button on the TradeFrame.
- Right-click the button or left-click the minimap icon to open config.
- Auto mode glows the button and preselects amounts based on class/whisper.

## Notes
- All trade actions occur only as a result of your click.
- No timers or automation; whispers set overrides but never execute trades.

