# FlameRewards - McDonald's GenUI Loyalty App

> Built at Flutter SF Hackathon 2026

A McDonald's loyalty rewards app where the UI generates itself. Instead of static screens, AI agents read real customer data and compose personalized quest challenges, rewards, and gamification experiences in real-time.

## What Makes This Different

Traditional loyalty apps show the same quests to every user. FlameRewards uses a multi-agent AI pipeline that reads each member's actual buying behavior and generates personalized challenges that didn't exist until that moment.

**Example:** Maya orders breakfast 6 times a month but never lunch. The AI reads this, cross-references cohort data showing gold breakfast regulars convert to Platinum by adding lunch, and generates: *"You've crushed 6 breakfasts this month! Try a lunch Big Mac this week — Gold members like you hit Platinum 74% faster."*

No one wrote that quest. The AI composed it from behavior + cohort signals.

## Demo

3 personas pull real data from Supabase:

| Persona | Tier | Flow |
|---------|------|------|
| **Jake** (Silver) | New user | 3-step onboarding quiz → AI cold start → personalized quests |
| **Maya** (Gold) | Power user | AI-generated quests → completed quest → spin wheel → McFlurry redemption |
| **Priya** (Platinum) | VIP | Premium AI quests with combo challenges, referrals, flash deals |

## Architecture

```
Supabase DB → Member Context → Agent Pipeline → Widget Specs → Flutter Renderer
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
              Orchestrator      Quest Agent      Cold Start Agent
              (Dart rules)     (LLM-powered)     (LLM-powered)
                    │                │                │
              Play & Earn      Reward Agent      Onboarding Quiz
              (Dart rules)     (Dart rules)      (3-step UI)
```

### Multi-Agent Pipeline

| Agent | LLM? | What It Does |
|-------|------|-------------|
| **Orchestrator** | No | Decides which agents to run based on tier/status |
| **Quest Agent** | Yes | Reads order history + cohort patterns → generates 3-4 diverse quest activities |
| **Cold Start Agent** | Yes | Quiz answers + cohort signals → 2 personalized starter quests |
| **Play & Earn Agent** | No | Spin wheel, scratch tickets, lottery draws (tier-gated) |
| **Reward Agent** | No | Points balance, redeemable rewards, checkout discounts |

### 8 Quest Activity Types

The LLM doesn't just change wording — it picks different activity structures based on behavior:

| Type | When AI Picks It | Visual |
|------|-----------------|--------|
| `streak` | User has active streak | Segmented flame bar |
| `try_new` | User only orders one category | "You always order X, try Y!" |
| `flash` | Lapsed user or promo window | Glowing border + countdown timer |
| `combo` | User hasn't tried full meals | Item chips (McMuffin + Coffee + Hash Brown) |
| `refer` | High-tier user | Handshake icon + dual reward |
| `daypart` | User only visits one time of day | "Morning person? Try dinner!" |
| `spend` | User makes small orders | Dollar progress bar ($12/$30) |
| `category` | User hasn't explored a category | "Order 3 McCafe drinks this week" |

## Stack

- **Frontend:** Flutter (Dart) — Web/Chrome
- **Database:** Supabase (PostgreSQL)
- **AI Model:** Featherless AI hosting Qwen/Qwen2.5-72B-Instruct
- **Packages:** `supabase_flutter`, `genui`, `openai_dart`

## Supabase Schema

```
users              → member profiles (tier, points, streak)
order_history      → past purchases per user
bonus_paths        → active quests/challenges
behavior_patterns  → cohort signals for AI personalization
play_earn_events   → gamification history
```

## Getting Started

### Prerequisites

- Flutter SDK (3.x+)
- Chrome browser
- Featherless AI API key ([featherless.ai](https://featherless.ai))

### Run

```bash
git clone https://github.com/swati070495/Flamerewards.git
cd Flamerewards
flutter pub get
flutter run -d chrome \
  --web-browser-flag="--disable-web-security" \
  --dart-define=FEATHERLESS_API_KEY=your_key_here
```

The `--disable-web-security` flag is needed for development because the Featherless API doesn't return CORS headers. The Featherless API key is passed via `--dart-define` so it never appears in source code.

The Supabase anon key in the code is public by design — it only allows read access through Row Level Security.

## Project Structure

```
lib/
├── main.dart                        Entry point
├── app.dart                         MaterialApp
├── home_page.dart                   Main UI (dark theme, phone frame,
│                                    persona switcher, quest cards,
│                                    order tab, bottom nav, all sheets)
├── agents/
│   ├── agent_pipeline.dart          Pipeline orchestration + cold start check
│   ├── orchestrator_agent.dart      Deterministic agent planning
│   ├── quest_agent.dart             LLM quest generation (8 activity types)
│   ├── cold_start_agent.dart        LLM cold start for new users
│   ├── play_earn_agent.dart         Gamification widgets
│   ├── reward_agent.dart            Reward widgets
│   ├── onboarding_result.dart       Quiz result data class
│   ├── agent_llm.dart               Featherless API client
│   ├── member_context.dart          Member data model
│   └── supabase_service.dart        Supabase client
├── widgets/
│   ├── spin_wheel_screen.dart       Animated spin wheel + redemption
│   └── onboarding_quiz.dart         3-step onboarding quiz
└── model/
    └── featherless_model_client.dart Streaming client
```

## Features

- **Dark premium UI** with phone frame mockup
- **Cold start onboarding** — 3-step quiz for new users, AI generates first quests
- **AI quest generation** — LLM reads buying behavior and picks from 8 activity types
- **Spin wheel** — animated wheel with redemption flow and QR code
- **Order tab** — visual points breakdown showing what you can get FREE
- **Points economy** — every menu item has a point cost, affordable items show FREE
- **Persona switching** — 3 real Supabase personas with different tiers and behaviors
- **Replay** — tap to regenerate quests (different every time from LLM)

## How The AI Works

### Without LLM (Static)
```
Supabase has fixed rows: "Breakfast Streak Champion" → always 3/5
Every time you tap Maya → same 3 quests. Nothing changes. Ever.
A product manager manually wrote each quest.
```

### With LLM (Dynamic)
```
Supabase order_history: Maya bought Egg McMuffin 6x, Latte 4x, Big Mac 2x
Supabase behavior_patterns: "gold morning regulars who add lunch convert 74%"

LLM reads both and GENERATES:
  "Maya, you've crushed 6 breakfasts! Try adding a lunch visit —
   Gold members like you who did this reached Platinum 74% faster"
```

The quest didn't exist in any database. The LLM invented it by combining:
- **Signal 1:** Real purchase history (she buys breakfast)
- **Signal 2:** Cohort data (gold breakfast regulars convert by adding lunch)
- **Signal 3:** Tier/points/streak context

Each persona switch generates fresh quests. Tap Replay to see different ones.

## LLM Calls Per Session

| Persona | LLM Calls | What |
|---------|-----------|------|
| Jake | 2 | Cold start (quiz + cohort) + Quest generation |
| Maya | 1 | Quest generation (behavior + cohort) |
| Priya | 1 | Quest generation (behavior + cohort) |

All other agents (Orchestrator, PlayEarn, Reward) use pure Dart — no LLM needed.

## Credits

Built at Flutter SF Hackathon 2026

Powered by Flutter, Supabase, Featherless AI (Qwen 72B), and Claude

Based on [GenUI Hackathon Starter](https://github.com/VGVentures/genui_hackathon_starter) by [Very Good Ventures](https://verygood.ventures)

---

[MIT License](LICENSE)
