# Get Shit Done

A macOS menu bar app that checks if you're actually working on what you said you'd work on.

It captures your screen periodically, sends the screenshot to an AI vision model, and nudges you with a notification if you've drifted off task.

## How It Works

1. You type what you're working on (e.g., "Fix login token refresh bug")
2. Hit Enter to start a focus session
3. Every N minutes, the app screenshots your screen
4. An AI model reads the screenshot and checks if it matches your declared task
5. If you're distracted, you get a notification like *"Wrong rabbit hole — get back to: Fix login token refresh bug"*

Screenshots are never stored. They're sent directly to the AI provider and discarded.

## Features

- **Menu bar task display** — your current task is always visible (inspired by [One Thing](https://sindresorhus.com/one-thing))
- **Multi-provider support** — OpenAI, Anthropic, or OpenRouter
- **Specific task matching** — catches you working on the wrong project/feature, not just "not working"
- **Configurable** — check interval, model selection, confidence threshold, menu bar preview length
- **Privacy-first** — API keys in Keychain, screenshots never saved to disk

## Supported Models

| Provider | Models |
|----------|--------|
| OpenAI | GPT-5.4, GPT-5.3, GPT-5.2, GPT-4.1, GPT-4o, and more |
| Anthropic | Claude Opus 4.6, Sonnet 4.6, Haiku 4.5, and more |
| OpenRouter | All of the above via a single API key |

## Cost

With GPT-5.2 checking every minute for a 10-hour day: **~$1.73/day**.

With GPT-4.1 Mini every 2 minutes: **~$0.17/day**.

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (`xcode-select --install`)
- An API key from OpenAI, Anthropic, or OpenRouter

## Build & Install

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/get-shit-done.git
cd get-shit-done

# Build
swift build -c release

# Create the app bundle
./build.sh

# Copy to Applications
cp -r ".build/Get Shit Done.app" /Applications/

# Launch
open "/Applications/Get Shit Done.app"
```

On first launch, macOS may block the unsigned app. Right-click the app → Open → Open to bypass Gatekeeper.

## Permissions

The app needs two permissions:

- **Screen Recording** — to capture screenshots for analysis
- **Notifications** — to alert you when you're distracted

Both are requested on first launch and can be managed in System Settings → Privacy & Security.

## Configuration

Click the gear icon in the popover to configure:

- **Provider & Model** — choose your AI provider and model
- **API Key** — stored securely in macOS Keychain
- **Check Interval** — how often to check (1–30 minutes)
- **Confidence Threshold** — how sure the model needs to be before flagging you

## License

MIT — see [LICENSE](LICENSE) for details.
