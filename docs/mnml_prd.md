# Product Requirements Document: Stock Analysis Platform

## Executive Summary

A web-based stock analysis platform that provides comprehensive stock evaluation through technical, fundamental, and emotional (sentiment) analysis. Built with React Router v7 frontend and Elixir Phoenix API backend, targeting individual investors and traders who want data-driven investment insights.

---

## 1. Product Overview

### 1.1 Vision
Create an intuitive, cost-effective stock analysis platform that democratizes access to multi-dimensional market insights by combining traditional technical/fundamental analysis with modern sentiment analysis from social platforms.

### 1.2 Target Users
- **Primary**: Individual retail investors (ages 25-45) who actively manage their own portfolios
- **Secondary**: Day traders seeking quick sentiment insights
- **Tertiary**: Financial enthusiasts learning about stock analysis

### 1.3 Success Metrics
- User engagement: Average 3+ stocks analyzed per session
- Retention: 40% weekly active users (WAU)
- Analysis completion: 70% of users view all three analysis tabs
- Performance: Page load under 2 seconds, API response under 500ms

---

## 2. API Strategy & Cost Optimization

### 2.1 Recommended API Stack

#### Core Stock Data APIs

**Alpha Vantage** (Primary - Stock Prices & Technical)
- **Free Tier**: 25 API requests/day, 5 requests/minute
- **Paid Plans**: Start at $49.99/month (500 requests/day)
- **Coverage**: Real-time and historical stock prices, technical indicators, fundamentals
- **Use For**: Technical analysis indicators (RSI, MACD, Bollinger Bands), intraday prices
- **Cost Efficiency**: Best free tier for starting out

**Financial Modeling Prep** (Secondary - Fundamentals)
- **Free Tier**: 250 requests/day
- **Paid Plans**: Start at $14/month (750 requests/day)
- **Coverage**: Financial statements, company fundamentals, SEC filings, ratios
- **Use For**: Fundamental analysis (P/E ratios, EPS, revenue, balance sheets)
- **Cost Efficiency**: Excellent value for fundamental data

**Finnhub** (Tertiary - News & Basic Data)
- **Free Tier**: 60 API calls/minute
- **Coverage**: Company news, basic fundamentals, forex
- **Use For**: Company news feed for context
- **Cost Efficiency**: Generous free tier for news

#### Sentiment Analysis APIs

**Reddit API (PRAW)**
- **Free Tier**: Yes (with Reddit account)
- **Rate Limits**: 60 requests/minute
- **Use For**: Scraping r/wallstreetbets, r/stocks, r/investing
- **Implementation**: Python Reddit API Wrapper (PRAW)

**Custom Sentiment Engine**
- Use OpenAI API or Anthropic Claude API for sentiment analysis
- **Cost**: ~$0.01-0.03 per analysis (using GPT-4o-mini or Claude Haiku)
- **Alternative**: Free local models (FinBERT, VADER) for basic sentiment

**StockTwits API** (Optional)
- **Free Tier**: 200 requests/hour
- **Use For**: Trader sentiment and trending tickers

**Unusual Whales API** (Institutional Data - Premium Feature)
- **Cost**: Included with existing Unusual Whales subscription
- **Rate Limits**: Monitor carefully, typically 1000-5000 requests/day depending on tier
- **Coverage**: Options flow, dark pool, congressional trading, insider activity, institutional holdings
- **Use For**: Institutional activity tab, smart money signals, enhanced recommendations
- **Implementation Strategy**: 
  - Cache aggressively (1-hour cache for most data)
  - Prioritize watchlist stocks
  - Background jobs for bulk updates
  - Rate limit per user if needed

### 2.2 Caching Strategy
To minimize API costs:
- **Phoenix Cache**: Use ETS (Erlang Term Storage) for in-memory caching
- **Cache Duration**:
  - Real-time prices: 15 seconds
  - Technical indicators: 1 hour (updated after market hours)
  - Fundamental data: 24 hours
  - Sentiment analysis: 30 minutes
  - Unusual Whales options flow: 1 hour
  - Unusual Whales dark pool: 1 hour
  - Unusual Whales congressional/insider trades: 24 hours
  - Unusual Whales institutional holdings: 7 days (13F filings are quarterly)
- **Redis**: For multi-instance deployments (future scaling)
- **Background Jobs**: Use Oban to refresh Unusual Whales data for popular stocks during off-peak hours

### 2.3 Cost Estimates (Monthly)
- **Development/Testing Phase**: $0-15 (free tiers only)
  - Unusual Whales: $0 (using existing subscription)
  - EAS Build: Free tier (30 builds/month)
- **Small User Base (< 100 active users)**: $75-125
  - Alpha Vantage: $49.99
  - FMP: $14
  - OpenAI/Anthropic: $20-30
  - Unusual Whales: $0 (existing subscription, monitor rate limits)
  - Apple Developer: $8.25/month ($99/year)
  - Google Play: $0 (one-time $25 paid)
  - EAS: Free tier sufficient
- **Growth Phase (100-1000 users)**: $250-500
  - Upgraded API tiers
  - Increased sentiment API usage
  - May need to upgrade Unusual Whales API tier if rate limits exceeded
  - EAS Production plan: $29-99/month (for more builds + bandwidth)
  - Expo Push Notifications: Free up to 100k/month

**Note**: Unusual Whales is cost-free initially using existing subscription. Monitor API usage and consider this a competitive advantage during MVP phase. Mobile app stores require annual fees but enable massive distribution potential.

---

## 3. Core Features

### 3.1 User Authentication & Management

#### 3.1.1 Account Features
- Email/password registration and login
- OAuth integration (Google, GitHub) - Phase 2
- Email verification
- Password reset flow
- User profile management

#### 3.1.2 Social Features
- Share analysis results via unique URL
- Friend invitations via email
- View friends' public watchlists (optional feature)
- Feedback submission form

#### 3.1.3 User Data
- Personal watchlist (save favorite stocks)
- Analysis history (last 20 viewed stocks)
- Notification preferences

### 3.2 Stock Search & Overview

#### 3.2.1 Search Functionality
- Auto-complete stock ticker search
- Company name search
- Popular/trending stocks section
- Recent searches (cached locally)

#### 3.2.2 Stock Overview Page
**Top Section - Overall Recommendation**
- Large recommendation badge: "Strong Buy", "Buy", "Hold", "Sell", "Strong Sell"
- Confidence score (0-100%)
- Current price with 24h change
- Key metrics: Market Cap, P/E Ratio, 52-week high/low
- Recommendation algorithm combines:
  - Technical score (30% weight)
  - Fundamental score (30% weight)
  - Sentiment score (20% weight)
  - Institutional activity score (20% weight - from Unusual Whales)

**Tab Navigation**
- Four tabs: Technical Analysis | Fundamental Analysis | Emotional Analysis | Institutional Activity
- Active tab highlighted
- URL updates with tab parameter (e.g., `/stocks/AAPL?tab=technical`)
- "Institutional Activity" badge to highlight premium data

### 3.3 Technical Analysis Tab

#### 3.3.1 Price Charts
- Interactive candlestick chart
- Timeframe toggles: 1D, 5D, 1M, 6M, 1Y, 5Y, Max
- Volume bars below price chart
- Zoom and pan capabilities

#### 3.3.2 Technical Indicators
Display calculated values and interpretation:
- **Moving Averages**: 20-day, 50-day, 200-day SMA
- **Momentum Indicators**: RSI (14-day), MACD, Stochastic Oscillator
- **Volatility**: Bollinger Bands, Average True Range (ATR)
- **Trend**: ADX (Average Directional Index)

#### 3.3.3 Technical Score
- Aggregated technical score (0-100)
- Buy/sell signal strength
- Support and resistance levels
- Visual indicators: Bullish/Bearish trend arrows

### 3.4 Fundamental Analysis Tab

#### 3.4.1 Financial Metrics
**Valuation Ratios**
- P/E Ratio (with industry average comparison)
- P/B Ratio
- PEG Ratio
- Price-to-Sales Ratio

**Profitability Metrics**
- Gross Margin
- Operating Margin
- Net Profit Margin
- ROE (Return on Equity)
- ROA (Return on Assets)

**Financial Health**
- Current Ratio
- Quick Ratio
- Debt-to-Equity Ratio
- Interest Coverage Ratio

#### 3.4.2 Financial Statements
- Income Statement (quarterly and annual)
- Balance Sheet
- Cash Flow Statement
- Historical data: Last 4 quarters, last 3 years

#### 3.4.3 Company Overview
- Business description
- Sector and industry
- Market cap and employee count
- Headquarters location
- Key executives

#### 3.4.4 Fundamental Score
- Aggregated fundamental score (0-100)
- Value assessment: Undervalued, Fairly Valued, Overvalued
- Growth potential rating
- Financial health rating

### 3.5 Emotional Analysis Tab

#### 3.5.1 Sentiment Overview
- Overall sentiment gauge: Very Bearish to Very Bullish
- Sentiment score (-100 to +100)
- Sentiment trend (7-day, 30-day change)
- Number of mentions tracked

#### 3.5.2 Social Media Breakdown
**Reddit Analysis**
- Sentiment from r/wallstreetbets, r/stocks, r/investing
- Top posts mentioning the stock (last 7 days)
- Upvote ratio and comment sentiment
- Trending discussion topics (word cloud or tags)

**StockTwits (Optional)**
- Bullish vs. Bearish percentage
- Message volume (24h, 7d)
- Top trending messages

**News Sentiment**
- Recent news headlines
- Sentiment analysis of news articles
- Publication date and source

#### 3.5.3 Smart Money Activity (Unusual Whales Integration)

**Section Header: "Institutional & Whale Activity"**

**Options Flow Signals**
- Unusual options activity summary (last 7 days)
- Large call/put trades indicating institutional sentiment
- Total premium traded (calls vs puts)
- Display format:
  - Trade details: "$2.4M in AAPL $180 calls exp 3/15"
  - Quantity, strike, expiration, premium
  - Bullish/Bearish indicator
- "Smart Money Score": Aggregated bullishness from options flow (0-100)
- Visualization: Options flow trend chart (7d, 30d)

**Dark Pool Activity**
- Dark pool volume compared to average
- Net buying/selling pressure
- Percentage of total volume
- Block trade trends chart
- Interpretation: "Dark pool buying 15% above average suggests institutional accumulation"

**Put/Call Ratio**
- Current put/call ratio for this stock
- Historical comparison (vs 30-day average)
- Market maker sentiment indicator

**Example Card Layout:**
```
🐋 Unusual Options Flow (Last 7 Days)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sentiment: Bullish ↗️
• $3.2M in call premium (vs $800K puts)
• Largest Trade: 500 contracts AAPL $180C 3/15
  Premium: $1.2M | Strike: $180 | Spot: $175
• Smart Money Score: 78/100 (Bullish)

🕶️ Dark Pool Activity
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• 2.1M shares (15% above average)
• Net Buying Pressure Detected
• Block Trades: 8 large buys, 3 sells
```

**Rate Limiting Strategy:**
- Cache Unusual Whales data for 1 hour
- Show "as of [timestamp]" for transparency
- Prioritize data for stocks in user watchlists
- Queue system for non-priority requests

#### 3.5.4 Trader Psychology Insights
- Fear & Greed indicators
- Retail vs. Institutional sentiment (if data available)
- Short interest data - Phase 2

#### 3.5.5 Social Platform Quotes
- Display 3-5 top posts/tweets with:
  - Platform icon
  - Username (anonymized or real)
  - Post excerpt (max 200 chars)
  - Timestamp
  - Engagement metrics (upvotes, likes)
  - Sentiment label (Bullish/Bearish/Neutral)

### 3.6 Institutional Activity Tab (Unusual Whales Premium Feature)

**Note:** This tab showcases institutional-grade data from Unusual Whales API. Initially available to all users with rate limiting, with potential to become premium feature in Phase 3-4.

#### 3.6.1 Tab Overview
Quick stats cards at top:
- **Smart Money Score**: 0-100 aggregate institutional sentiment
- **Institutional Flow**: Net call/put premium (7d)
- **Dark Pool Activity**: Above/below average indicator
- **Insider Sentiment**: Net buying/selling (90d)

#### 3.6.2 Options Flow Feed

**Recent Unusual Activity**
- Live or recent feed of unusual options trades (last 7 days)
- Table columns:
  - Time/Date
  - Type (Call/Put)
  - Strike & Expiration
  - Premium ($)
  - Quantity
  - Spot price at trade
  - Sentiment (Bullish/Bearish)
  - Trade side (Buy/Sell)
- Filters:
  - Calls only / Puts only
  - Minimum premium threshold
  - Expiration date range
- Highlight trades > $1M premium in gold
- Click trade for detailed breakdown

**Options Flow Analytics**
- Total call premium vs put premium (7d, 30d)
- Put/Call ratio trend chart
- Most active strike prices
- Implied volatility changes
- Open interest changes on key strikes

**Interpretation Widget**
Auto-generated insights:
- "Heavy call buying at $180 strike suggests bullish outlook for next month"
- "Put/call ratio of 0.3 indicates strong bullish sentiment"

#### 3.6.3 Dark Pool Activity

**Dark Pool Summary**
- Total dark pool volume (today, 7d, 30d)
- Percentage of total daily volume
- Dark pool vs lit exchange ratio
- Net buying/selling indicator

**Dark Pool Transactions**
- Recent large block trades
- Table showing:
  - Date/Time
  - Share quantity
  - Price level
  - Estimated value
  - Buy/Sell indicator (when detectable)

**Dark Pool Chart**
- Daily dark pool volume bars
- Overlay with stock price
- 30-day view to spot patterns
- Annotation: "Dark pool volume spike often precedes price moves"

#### 3.6.4 Congressional Trading

**Recent Congressional Activity**
- List of congressional trades for this stock (last 90 days)
- Columns:
  - Representative/Senator name
  - Transaction type (Buy/Sell)
  - Date filed
  - Amount range ($15K-$50K, $50K-$100K, etc.)
  - Party affiliation
- Net congressional position: Bullish/Bearish/Neutral
- Timeline view of trades

**Congressional Sentiment Score**
- Aggregate: Are politicians buying or selling?
- "5 representatives bought, 1 sold in last 90 days"
- Historical accuracy widget: "Congressional buys in this stock have been profitable 70% of the time"

**Disclaimer**: 
"Congressional trading data is publicly disclosed per the STOCK Act. Trades are reported 30-45 days after execution. This is informational only and not trading advice."

#### 3.6.5 Insider Trading Activity

**Corporate Insider Transactions**
- Recent insider buys/sells (last 90 days)
- Table columns:
  - Insider name and title (CEO, CFO, Director, etc.)
  - Transaction type
  - Shares traded
  - Price per share
  - Total value
  - Date
- Filter by:
  - Transaction type (buys/sells)
  - Insider role
  - Amount threshold

**Insider Sentiment Analysis**
- Net insider buying/selling ratio
- Aggregate dollar amount: Net buying or selling?
- Interpretation: "Insiders have purchased $2.3M worth of shares, suggesting confidence"
- Cluster detection: "3 executives bought within same week"

**Insider Ownership Trends**
- Chart showing insider ownership percentage over time
- Notable changes highlighted

#### 3.6.6 Institutional Holdings

**Top Institutional Holders**
- List of top 10-20 hedge funds/institutions holding this stock
- Columns:
  - Institution name (Vanguard, BlackRock, etc.)
  - Shares held
  - Portfolio percentage
  - Value of holdings
  - Change from last quarter (%, shares)
  - Last report date (13F filing)

**Institutional Flow Analysis**
- Net institutional buying/selling this quarter
- Number of institutions increasing vs decreasing positions
- New positions opened vs positions closed
- Smart money concentration: "Top 3 institutions own 18% of shares"

**Institutional Ownership Chart**
- Pie chart: Institutional vs retail ownership
- Trend: Institutional ownership increasing or decreasing over 4 quarters

#### 3.6.7 Market Sentiment Indicators

**Market Tide (Unusual Whales Proprietary)**
- Overall market sentiment gauge (-100 to +100)
- Context: "Broader market is bullish, supporting upside for individual stocks"
- Correlation note: "This stock typically follows market tide"

**Sector Sentiment**
- How this stock's sector is performing on institutional metrics
- Relative strength: Is this stock attracting more whale activity than sector peers?

#### 3.6.8 Integration Features

**Watchlist Integration**
- "Alert me on unusual whale activity" toggle for watchlist stocks
- Email/push notification when unusual options flow detected

**Paper Trading Integration**
- "Trade Ideas from Whales" section
- Suggest trades based on institutional flow
- Example: "AAPL seeing heavy call buying - consider adding to paper portfolio"
- Track correlation between paper trades and whale activity

**Recommendation Impact**
- Show how institutional activity affects overall recommendation
- "Smart Money Score increased recommendation from Buy to Strong Buy"

#### 3.6.9 Educational Content

**First-time User Guide**
- Explain what each metric means
- "What is dark pool trading?" tooltips
- "How to interpret options flow" tutorial
- Video explainers (Phase 2)

**Glossary Links**
- Inline definitions for terms like "put/call ratio", "block trade", "13F filing"
- Link to comprehensive glossary

### 3.7 Paper Trading System

#### 3.7.1 Portfolio Management

**Portfolio Creation**
- Each user gets one default paper trading portfolio on registration
- Starting virtual balance: $100,000 (configurable by user on creation)
- Portfolio naming and description
- Multiple portfolios support (Phase 2): e.g., "Conservative", "Aggressive Growth"

**Portfolio Dashboard**
- Total portfolio value (cash + holdings value)
- Cash available for trading
- Total gain/loss ($ and %)
- Holdings table with columns:
  - Ticker symbol
  - Company name
  - Quantity owned
  - Average cost per share
  - Current price
  - Total value
  - Gain/loss ($ and %)
  - % of portfolio
- Portfolio composition pie chart
- Performance chart (value over time): 1W, 1M, 3M, 1Y, All

**Quick Stats Cards**
- Total Return: $X,XXX (+X.XX%)
- Best Performer: TICKER (+XX%)
- Worst Performer: TICKER (-XX%)
- Total Trades: XX
- Win Rate: XX%

#### 3.7.2 Trading Functionality

**Trade Execution**
- Accessible via "Trade" button on any stock analysis page
- Trade modal/drawer with:
  - Buy/Sell tabs
  - Quantity input (shares)
  - Current price display (auto-updates)
  - Total cost calculation (quantity × price)
  - Available cash/shares display
  - Preview summary before confirmation
  - "Execute Trade" confirmation button

**Order Types (Phase 1)**
- Market orders only (executed at current cached price)
- Instant execution (no order queue)

**Order Types (Phase 2)**
- Limit orders: Execute when price reaches specified level
- Stop-loss orders: Automatically sell to limit losses
- Good-til-cancelled (GTC) orders
- Day orders

**Trade Validation**
- Prevent buying with insufficient cash
- Prevent selling more shares than owned
- Minimum trade size: 1 share
- Maximum order size: 10,000 shares (prevent abuse)
- Warning if trade exceeds 20% of portfolio value

**Trade Confirmation**
- Success message with trade summary
- Option to "View Portfolio" or "Continue Analyzing"
- Transaction recorded in history

#### 3.7.3 Transaction History

**Transaction Log**
- Paginated list of all trades (20 per page)
- Columns:
  - Date/time
  - Ticker
  - Type (Buy/Sell)
  - Quantity
  - Price per share
  - Total amount
  - Portfolio name (if multiple portfolios)
- Filtering:
  - By ticker
  - By type (buy/sell)
  - By date range
  - By portfolio
- Export to CSV
- Search functionality

**Transaction Details**
- Click any transaction to view full details
- Shows market conditions at time of trade
- Link to current analysis of that stock
- Notes field (optional, user can add reasoning)

#### 3.7.4 Performance Analytics

**Returns Calculation**
- Total return: (Current Value - Starting Balance) / Starting Balance
- Realized gains: From completed sell transactions
- Unrealized gains: From current holdings
- Time-weighted return (TWR) for deposits/withdrawals (Phase 2)

**Performance Metrics**
- Best trade (highest % gain)
- Worst trade (highest % loss)
- Win rate: % of profitable trades
- Average gain per winning trade
- Average loss per losing trade
- Largest holding by value
- Most traded stock

**Benchmarking (Phase 2)**
- Compare portfolio performance vs S&P 500
- Compare vs Dow Jones
- Compare vs NASDAQ
- Visual comparison chart
- Relative strength indicator

#### 3.7.5 Integration with Analysis Features

**From Analysis to Trade**
- Prominent "Add to Portfolio" button on each stock page
- Pre-fills ticker in trade modal
- Shows recommendation context: "You're buying a Strong Buy stock"
- Option to add trade note: "Buying based on technical analysis bullish crossover"

**From Trade to Analysis**
- "Analyze" button on each portfolio holding
- Deep link to stock analysis page
- "Re-evaluate" feature: Compare current recommendation to when you bought

**Recommendation Tracking**
- Tag trades with the recommendation at purchase time
- Performance report: "Your Strong Buy picks are up 8% on average"
- Recommendation accuracy metrics
- "Most accurate indicator" insights

#### 3.7.6 Social & Gamification

**Leaderboards (Phase 2)**
- Friends leaderboard (opt-in)
- Rankings by:
  - Total return %
  - Absolute gain $
  - Win rate
  - Best trade
- Time periods: This week, This month, All time
- Privacy: Users can opt out or make anonymous

**Achievements (Phase 2)**
- First Trade
- 10 Trades milestone
- Profit Milestone ($10k gains)
- Perfect Week (all trades profitable)
- Diversification Pro (10+ different holdings)
- Diamond Hands (Hold for 30+ days)
- Quick Trader (10 trades in one day)
- Whale Watcher (Trade based on unusual whales alert)

**Portfolio Sharing**
- Generate shareable link to portfolio snapshot
- Shows current holdings and performance
- Does not show transaction history (privacy)
- Can be embedded on social media
- "Copy this portfolio" feature for other users

#### 3.7.7 Educational Features

**Paper Trading Tutorial**
- First-time user walkthrough
- Explains virtual nature of trades
- Best practices guide
- Risk management tips

**Performance Insights**
- AI-generated portfolio analysis (Phase 2)
- Suggestions: "Your portfolio is heavily weighted in tech stocks - consider diversification"
- Risk assessment: "Your current holdings have high volatility"
- Sector exposure breakdown

**Learning Resources**
- Link to articles about trading strategies
- Glossary of trading terms
- Video tutorials (Phase 2)

#### 3.7.8 Risk Management Features

**Diversification Alerts**
- Warning if >30% in single stock
- Sector concentration alerts
- Correlation warnings (Phase 2)

**Portfolio Risk Metrics (Phase 2)**
- Beta (portfolio volatility vs market)
- Sharpe ratio (risk-adjusted return)
- Maximum drawdown
- Value at Risk (VaR)

**Auto-Stop Loss (Optional Phase 2)**
- Set automatic stop-loss on all positions
- Configurable percentage (e.g., -10%)
- Helps simulate real trading discipline

## 4. Technical Architecture

### 4.0 Monorepo Architecture

**Project Structure:**
```
stock-analysis/                    # Root monorepo
├── apps/
│   ├── web/                      # Next.js web application
│   ├── mobile/                   # React Native mobile app
│   └── api/                      # Phoenix backend API
├── packages/
│   ├── ui/                       # Shared UI components (React)
│   ├── tailwind-config/          # Shared Tailwind configuration
│   ├── typescript-config/        # Shared TypeScript configs
│   ├── api-client/              # Shared API client logic
│   └── types/                    # Shared TypeScript types
├── package.json                  # Root package.json
├── turbo.json                    # Turborepo configuration
└── pnpm-workspace.yaml          # PNPM workspace config
```

**Monorepo Tool: Turborepo**
- Fast, scalable build system
- Intelligent caching
- Parallel task execution
- Remote caching support (Vercel)
- Perfect for Next.js + React Native

**Package Manager: PNPM**
- Faster than npm/yarn
- Efficient disk space usage
- Workspaces support
- Better for monorepos

**Shared Code Strategy:**
```
┌─────────────────────────────────────┐
│   Next.js Web (apps/web)            │
│   - Web-specific UI                 │
│   - SSR/SSG pages                   │
└──────────┬──────────────────────────┘
           │
           ├─────► packages/ui (Shared Components)
           ├─────► packages/api-client (API Logic)
           ├─────► packages/types (TypeScript Types)
           │
┌──────────▼──────────────────────────┐
│   React Native (apps/mobile)        │
│   - Mobile-specific UI              │
│   - Native features                 │
└──────────┬──────────────────────────┘
           │
           │ Both call same API
           │
┌──────────▼──────────────────────────┐
│   Phoenix API (apps/api)            │
│   - Single source of truth          │
│   - JWT authentication              │
│   - Business logic                  │
└─────────────────────────────────────┘
```

**Code Reuse Breakdown:**
- **100% Reused**: API client, types, business logic, utilities
- **80% Reused**: UI components (with platform adapters)
- **50% Reused**: Navigation logic, state management
- **0% Reused**: Platform-specific code (native modules, SSR)

### 4.1 Frontend Framework Choice: Next.js + React Native

**Why This Stack:**

**Next.js (Web):**
- Solo developer building Shopify sites (Next.js is industry standard)
- Superior deployment experience (Vercel)
- SEO for public stock pages
- Server-side rendering for performance
- Skills transferable across projects

**React Native (Mobile):**
- **Share code with Next.js**: Both use React, TypeScript, same component patterns
- **Single language**: JavaScript/TypeScript for web + mobile
- **Expo**: Simplifies React Native development for solo devs
- **Over-the-Air Updates**: Update app without App Store review
- **Native performance**: Better than web view or hybrid approaches

**Tailwind CSS Strategy:**
- **Web (Next.js)**: Native Tailwind CSS support
- **Mobile (React Native)**: NativeWind (Tailwind for React Native)
- **Shared config**: One `tailwind.config.js` for both platforms
- **Same class names**: `className="bg-blue-500 rounded-lg"` works on both

**Benefits of Monorepo:**
- ✅ Share TypeScript types between web, mobile, and API
- ✅ Single source of truth for API client
- ✅ Reuse UI components with minimal platform-specific code
- ✅ Consistent styling with Tailwind
- ✅ Single deploy command for all apps
- ✅ No package publishing needed

### 4.2 Web Application Stack (Next.js)
- **Framework**: Next.js 14+ (App Router)
- **Language**: TypeScript
- **State Management**: Zustand or React Context API (for client-side state)
- **Data Fetching**: Next.js Server Components + React Query (for client components)
- **Charting**: Lightweight Charts (TradingView) or Recharts
- **Styling**: Tailwind CSS
- **Build Tool**: Next.js built-in (Turbopack/Webpack)
- **Deployment**: Vercel

**Key Next.js Features Used:**
- Server Components (default) for data fetching from Phoenix API
- Client Components ('use client') for interactive features
- App Router for file-based routing
- Automatic code splitting per route
- Image optimization with next/image
- Built-in SEO with metadata API
- Server-side rendering (SSR) for public pages
- Static generation (SSG) where applicable

### 4.2 Web Application Stack (Next.js)

**Location**: `apps/web/`

- **Framework**: Next.js 14+ (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: Zustand (shared state) + React Query (server state)
- **Data Fetching**: Next.js Server Components + React Query (client components)
- **Charting**: Lightweight Charts (TradingView) or Recharts
- **UI Components**: Shadcn/ui (built on Radix UI)
- **Forms**: React Hook Form + Zod validation
- **Deployment**: Vercel

**Key Features:**
- Server-side rendering for performance
- File-based routing with App Router
- Automatic code splitting
- Image optimization with next/image
- Built-in SEO with metadata API

### 4.3 Mobile Application Stack (React Native + Expo)

**Location**: `apps/mobile/`

- **Framework**: React Native with Expo SDK 50+
- **Language**: TypeScript
- **Styling**: NativeWind (Tailwind CSS for React Native)
- **Navigation**: Expo Router (file-based, like Next.js)
- **State Management**: Zustand (shared with web) + React Query
- **Charts**: Victory Native (React Native charts)
- **UI Components**: Shared from `packages/ui` + React Native Paper
- **Forms**: React Hook Form + Zod (shared validation)
- **Build**: EAS Build (Expo Application Services)
- **OTA Updates**: Expo Updates
- **Deployment**: App Store + Google Play (via EAS Submit)

**Expo Benefits for Solo Dev:**
- ✅ No Xcode/Android Studio required for most development
- ✅ Test on physical device instantly with Expo Go
- ✅ Over-the-air updates (fix bugs without app store review)
- ✅ EAS Build handles iOS + Android builds in cloud
- ✅ Managed workflow simplifies native modules

**NativeWind (Tailwind for React Native):**
```tsx
// Same class names work on web and mobile!
<View className="bg-blue-500 rounded-lg p-4 shadow-md">
  <Text className="text-white font-bold text-lg">Hello</Text>
</View>
```

**File-based Routing with Expo Router:**
```
apps/mobile/app/
├── (tabs)/                    # Tab navigator
│   ├── _layout.tsx           # Tabs setup
│   ├── index.tsx             # Home tab
│   ├── portfolio.tsx         # Portfolio tab
│   └── watchlist.tsx         # Watchlist tab
├── stocks/
│   └── [ticker].tsx          # /stocks/AAPL
└── _layout.tsx               # Root layout
```

**Platform-Specific Features:**
- Push notifications (Expo Notifications)
- Biometric authentication (Face ID / Fingerprint)
- Haptic feedback
- Share API integration
- Deep linking support

### 4.4 Shared Packages

**Location**: `packages/`

#### **packages/ui**
Shared React components that work on web and mobile
```
packages/ui/
├── src/
│   ├── button.tsx           # Platform-agnostic button
│   ├── card.tsx             # Card component
│   ├── input.tsx            # Form input
│   ├── stock-chart.tsx      # Stock price chart
│   └── adapters/            # Platform adapters
│       ├── web.tsx
│       └── native.tsx
├── package.json
└── tsconfig.json
```

**Component Strategy:**
```tsx
// packages/ui/src/button.tsx
import { ButtonWeb } from './adapters/web'
import { ButtonNative } from './adapters/native'

// Auto-selects based on platform
export const Button = Platform.OS === 'web' ? ButtonWeb : ButtonNative
```

#### **packages/api-client**
Shared API client for Phoenix backend
```typescript
// packages/api-client/src/client.ts
export class ApiClient {
  constructor(private baseUrl: string, private token?: string) {}
  
  async getStock(ticker: string) {
    return this.fetch(`/api/stocks/${ticker}`)
  }
  
  // Works identically on web and mobile
}
```

#### **packages/types**
Shared TypeScript types
```typescript
// packages/types/src/stock.ts
export interface Stock {
  ticker: string
  name: string
  price: number
  change: number
  // Used by web, mobile, and API validation
}
```

#### **packages/tailwind-config**
Shared Tailwind configuration
```javascript
// packages/tailwind-config/index.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',
        bullish: '#10b981',
        bearish: '#ef4444'
      }
    }
  }
}

// Used by both apps/web and apps/mobile
```

### 4.5 Backend Stack (Phoenix)
- **Framework**: Elixir Phoenix 1.7+
- **Database**: PostgreSQL 15+
- **Cache**: ETS (built-in) or Redis
- **Authentication**: Phoenix Guardian (JWT)
- **API**: RESTful JSON API
- **Background Jobs**: Oban
- **WebSockets**: Phoenix Channels (for real-time updates)
- **Deployment**: Fly.io

### 4.3 Architecture Overview

### 4.6 Architecture Overview

**Three-Tier Architecture with Monorepo:**
```
┌─────────────────────────────────────┐
│   Next.js Web (Vercel)              │
│   apps/web/                          │
│   - Desktop browser experience      │
│   - SSR for performance             │
│   - SEO optimized                   │
└──────────────┬──────────────────────┘
               │
               │  Shared packages:
               │  - api-client
               │  - types
               │  - ui components
               │
┌──────────────┴──────────────────────┐
│   React Native Mobile (EAS)         │
│   apps/mobile/                       │
│   - iOS + Android apps              │
│   - Native performance              │
│   - Push notifications              │
└──────────────┬──────────────────────┘
               │
               │ Both consume same API
               │ HTTPS REST + WebSocket
               │ JWT Authentication
               │
┌──────────────▼──────────────────────┐
│   Phoenix API Backend (Fly.io)      │
│   apps/api/                          │
│   - Single API for all clients      │
│   - JWT Authentication              │
│   - Business Logic                  │
│   - External API integrations       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   PostgreSQL Database (Fly.io)      │
└─────────────────────────────────────┘
```

**Communication Flow:**
1. User visits Next.js web app OR opens React Native mobile app
2. Client fetches data from Phoenix API (server components for web, React Query for mobile)
3. Phoenix validates JWT, processes request
4. Phoenix returns JSON response
5. Client renders UI (Next.js SSR for web, native rendering for mobile)
6. Real-time updates via Phoenix Channels WebSocket (both platforms)

**Monorepo Benefits:**
- Share API client code between web and mobile
- Share TypeScript types across all apps
- Share UI components with platform adapters
- Single Tailwind config for consistent styling
- Deploy all apps with one command

**Environment Configuration:**
- Next.js: `NEXT_PUBLIC_API_URL` → Phoenix API
- React Native: `EXPO_PUBLIC_API_URL` → Phoenix API (same)
- Phoenix: CORS allows both web domain and mobile app
- JWT tokens work identically on both platforms

**CORS Configuration (Phoenix):**
```elixir
# lib/stock_analysis_web/endpoint.ex
plug Corsica,
  origins: [
    "http://localhost:3000",              # Next.js local dev
    "http://localhost:8081",              # Expo local dev
    "https://stockanalysis.com",          # Production web
    ~r/\.vercel\.app$/,                   # Vercel previews
    ~r/^exp:\/\/.*$/,                     # Expo development
    "capacitor://localhost",              # Mobile WebView (if needed)
    "ionic://localhost"                   # Mobile WebView (if needed)
  ],
  allow_headers: ["authorization", "content-type"],
  allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allow_credentials: true,
  max_age: 600
```

**Authentication Flow (Same for Web + Mobile):**
```
1. User logs in via form (Next.js or React Native)
2. Client sends credentials to Phoenix /api/auth/login
3. Phoenix validates and returns JWT token
4. Client stores token:
   - Web: httpOnly cookie or localStorage
   - Mobile: SecureStore (Expo) - encrypted storage
5. Subsequent requests include: Authorization: Bearer {token}
6. Phoenix validates JWT on each request (platform-agnostic)
```

### 4.7 Data Models

#### User Schema
```elixir
schema "users" do
  field :email, :string
  field :password_hash, :string
  field :username, :string
  field :email_verified, :boolean, default: false
  field :avatar_url, :string
  
  has_many :watchlists, Watchlist
  has_many :analysis_history, AnalysisHistory
  
  timestamps()
end
```

#### Watchlist Schema
```elixir
schema "watchlists" do
  belongs_to :user, User
  field :ticker, :string
  field :added_at, :utc_datetime
  
  timestamps()
end
```

#### AnalysisHistory Schema
```elixir
schema "analysis_history" do
  belongs_to :user, User
  field :ticker, :string
  field :viewed_at, :utc_datetime
  
  timestamps()
end
```

#### StockCache Schema (for API response caching)
```elixir
schema "stock_cache" do
  field :ticker, :string
  field :data_type, :string # "technical", "fundamental", "sentiment"
  field :data, :map
  field :expires_at, :utc_datetime
  
  timestamps()
end
```

#### PaperPortfolio Schema
```elixir
schema "paper_portfolios" do
  belongs_to :user, User
  field :name, :string
  field :description, :string
  field :starting_balance, :decimal
  field :cash_balance, :decimal
  field :is_active, :boolean, default: true
  
  has_many :holdings, PaperHolding
  has_many :transactions, PaperTransaction
  
  timestamps()
end
```

#### PaperHolding Schema
```elixir
schema "paper_holdings" do
  belongs_to :portfolio, PaperPortfolio
  field :ticker, :string
  field :quantity, :decimal
  field :average_cost, :decimal
  field :total_cost, :decimal
  field :last_updated, :utc_datetime
  
  timestamps()
end
```

#### PaperTransaction Schema
```elixir
schema "paper_transactions" do
  belongs_to :portfolio, PaperPortfolio
  field :ticker, :string
  field :transaction_type, :string # "buy", "sell"
  field :quantity, :decimal
  field :price_per_share, :decimal
  field :total_amount, :decimal
  field :recommendation_at_time, :string # "Strong Buy", "Buy", etc.
  field :notes, :text
  field :executed_at, :utc_datetime
  
  timestamps()
end
```

### 4.8 Phoenix Contexts

**Accounts Context**
- User registration, authentication
- Password reset, email verification
- Profile management

**Stocks Context**
- Stock search and lookup
- Fetch stock data from external APIs
- Cache management

**Analysis Context**
- Technical analysis calculations
- Fundamental analysis aggregation
- Overall recommendation generation

**Sentiment Context**
- Social media data aggregation
- Sentiment score calculation
- News sentiment analysis

**InstitutionalActivity Context**
- Unusual Whales API integration
- Options flow analysis and caching
- Dark pool data aggregation
- Congressional trading data
- Insider trading data
- Institutional holdings tracking
- Smart money score calculation
- Rate limiting and request queue management

**Watchlist Context**
- CRUD operations for user watchlists
- Analysis history tracking

**PaperTrading Context**
- Portfolio creation and management
- Trade execution (buy/sell)
- Holdings calculation and updates
- Transaction recording
- Performance metrics calculation
- Portfolio valuation (real-time with cached prices)
- Leaderboard generation

### 4.9 API Endpoints (Phoenix Backend)

**Note**: All API endpoints are served by Phoenix. Single API serves both Next.js web and React Native mobile clients.

#### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/forgot-password` - Request password reset
- `POST /api/auth/reset-password` - Reset password

#### Stocks
- `GET /api/stocks/search?q={query}` - Search stocks
- `GET /api/stocks/{ticker}` - Get stock overview
- `GET /api/stocks/{ticker}/technical` - Get technical analysis
- `GET /api/stocks/{ticker}/fundamental` - Get fundamental analysis
- `GET /api/stocks/{ticker}/sentiment` - Get sentiment analysis
- `GET /api/stocks/{ticker}/institutional` - Get institutional activity (Unusual Whales data)
- `GET /api/stocks/trending` - Get trending stocks

#### Institutional Activity (Unusual Whales)
- `GET /api/institutional/{ticker}/options-flow` - Get recent options flow
- `GET /api/institutional/{ticker}/dark-pool` - Get dark pool activity
- `GET /api/institutional/{ticker}/congressional` - Get congressional trades
- `GET /api/institutional/{ticker}/insider-trades` - Get insider trading activity
- `GET /api/institutional/{ticker}/holdings` - Get institutional holdings (13F data)
- `GET /api/institutional/market-tide` - Get overall market sentiment
- `GET /api/institutional/{ticker}/smart-money-score` - Get aggregated institutional score

#### User
- `GET /api/user/profile` - Get user profile
- `PUT /api/user/profile` - Update profile
- `GET /api/user/watchlist` - Get user watchlist
- `POST /api/user/watchlist` - Add to watchlist
- `DELETE /api/user/watchlist/{ticker}` - Remove from watchlist
- `GET /api/user/history` - Get analysis history

#### Sharing
- `POST /api/shares/create` - Generate shareable link
- `GET /api/shares/{id}` - Get shared analysis (public)

#### Paper Trading
- `GET /api/paper-trading/portfolios` - Get user's portfolios
- `POST /api/paper-trading/portfolios` - Create new portfolio
- `GET /api/paper-trading/portfolios/{id}` - Get portfolio details
- `PUT /api/paper-trading/portfolios/{id}` - Update portfolio
- `DELETE /api/paper-trading/portfolios/{id}` - Delete portfolio (with confirmation)
- `GET /api/paper-trading/portfolios/{id}/performance` - Get performance metrics
- `POST /api/paper-trading/portfolios/{id}/trade` - Execute a trade
- `GET /api/paper-trading/portfolios/{id}/holdings` - Get current holdings
- `GET /api/paper-trading/portfolios/{id}/transactions` - Get transaction history
- `GET /api/paper-trading/portfolios/{id}/transactions/{transaction_id}` - Get transaction details
- `POST /api/paper-trading/portfolios/{id}/share` - Generate shareable portfolio link
- `GET /api/paper-trading/leaderboard` - Get friends leaderboard (Phase 2)

### 4.10 Monorepo File Structure

**Complete Project Structure:**
```
stock-analysis/                           # Root monorepo
├── apps/
│   ├── web/                             # Next.js web app
│   │   ├── app/
│   │   │   ├── layout.tsx              # Root layout
│   │   │   ├── page.tsx                # Homepage
│   │   │   ├── (auth)/
│   │   │   │   ├── login/page.tsx
│   │   │   │   └── register/page.tsx
│   │   │   ├── stocks/
│   │   │   │   ├── [ticker]/page.tsx   # /stocks/AAPL
│   │   │   │   └── search/page.tsx
│   │   │   ├── portfolio/
│   │   │   │   └── page.tsx
│   │   │   └── watchlist/
│   │   │       └── page.tsx
│   │   ├── components/                  # Web-specific components
│   │   ├── lib/
│   │   ├── public/
│   │   ├── tailwind.config.js           # Extends shared config
│   │   ├── next.config.js
│   │   └── package.json
│   │
│   ├── mobile/                          # React Native app (Expo)
│   │   ├── app/
│   │   │   ├── _layout.tsx             # Root layout
│   │   │   ├── (tabs)/                 # Tab navigator
│   │   │   │   ├── _layout.tsx
│   │   │   │   ├── index.tsx           # Home tab
│   │   │   │   ├── portfolio.tsx       # Portfolio tab
│   │   │   │   └── watchlist.tsx       # Watchlist tab
│   │   │   ├── (auth)/
│   │   │   │   ├── login.tsx
│   │   │   │   └── register.tsx
│   │   │   ├── stocks/
│   │   │   │   └── [ticker].tsx        # /stocks/AAPL
│   │   │   └── modal.tsx
│   │   ├── components/                  # Mobile-specific components
│   │   ├── assets/
│   │   ├── app.json                     # Expo config
│   │   ├── tailwind.config.js           # NativeWind config
│   │   └── package.json
│   │
│   └── api/                             # Phoenix backend
│       ├── lib/
│       │   ├── stock_analysis/          # Business logic
│       │   └── stock_analysis_web/      # Web layer
│       ├── priv/
│       │   └── repo/migrations/
│       ├── config/
│       ├── mix.exs
│       └── mix.lock
│
├── packages/                            # Shared code
│   ├── ui/                             # Shared UI components
│   │   ├── src/
│   │   │   ├── button.tsx
│   │   │   ├── card.tsx
│   │   │   ├── stock-card.tsx
│   │   │   ├── chart.tsx
│   │   │   └── adapters/               # Platform adapters
│   │   │       ├── web.tsx
│   │   │       └── native.tsx
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── api-client/                     # Shared API client
│   │   ├── src/
│   │   │   ├── client.ts              # Base client
│   │   │   ├── stocks.ts              # Stock endpoints
│   │   │   ├── auth.ts                # Auth endpoints
│   │   │   ├── portfolio.ts           # Portfolio endpoints
│   │   │   └── institutional.ts       # Unusual Whales
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── types/                          # Shared TypeScript types
│   │   ├── src/
│   │   │   ├── stock.ts
│   │   │   ├── user.ts
│   │   │   ├── portfolio.ts
│   │   │   └── api.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── tailwind-config/                # Shared Tailwind config
│   │   ├── index.js                   # Base config
│   │   ├── web.js                     # Web preset
│   │   ├── native.js                  # NativeWind preset
│   │   └── package.json
│   │
│   ├── typescript-config/              # Shared TS configs
│   │   ├── base.json
│   │   ├── nextjs.json
│   │   ├── react-native.json
│   │   └── package.json
│   │
│   └── utils/                          # Shared utilities
│       ├── src/
│       │   ├── formatters.ts          # Date, price formatting
│       │   ├── calculations.ts        # Financial calculations
│       │   └── validators.ts          # Zod schemas
│       └── package.json
│
├── .github/
│   └── workflows/
│       ├── web.yml                     # Deploy Next.js
│       ├── mobile.yml                  # Build mobile apps
│       └── api.yml                     # Deploy Phoenix
│
├── package.json                        # Root package.json
├── pnpm-workspace.yaml                # PNPM workspaces
├── turbo.json                         # Turborepo config
├── tsconfig.json                      # Root TS config
└── README.md
```

**Package Dependencies:**

```json
// apps/web/package.json
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/api-client": "workspace:*",
    "@repo/types": "workspace:*",
    "@repo/utils": "workspace:*",
    "next": "14.x",
    "react": "18.x"
  }
}

// apps/mobile/package.json  
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/api-client": "workspace:*",
    "@repo/types": "workspace:*",
    "@repo/utils": "workspace:*",
    "expo": "~50.x",
    "react-native": "0.73.x",
    "nativewind": "^4.0.0"
  }
}
```

**Turborepo Configuration:**

```json
// turbo.json
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**", ".expo/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "type-check": {
      "dependsOn": ["^build"]
    }
  }
}
```

**Scripts:**

```json
// package.json (root)
{
  "scripts": {
    "dev": "turbo dev",
    "dev:web": "turbo dev --filter=web",
    "dev:mobile": "turbo dev --filter=mobile",
    "build": "turbo build",
    "build:web": "turbo build --filter=web",
    "build:mobile": "turbo build --filter=mobile",
    "lint": "turbo lint",
    "type-check": "turbo type-check",
    "clean": "turbo clean && rm -rf node_modules"
  }
}
```

### 4.11 Code Sharing Examples

**Shared API Client (packages/api-client):**
```typescript
// packages/api-client/src/client.ts
export class StockApiClient {
  constructor(private baseUrl: string) {}
  
  async getStock(ticker: string, token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json'
    }
    
    if (token) {
      headers['Authorization'] = `Bearer ${token}`
    }
    
    const response = await fetch(`${this.baseUrl}/api/stocks/${ticker}`, {
      headers
    })
    
    return response.json()
  }
}

// Used identically in web and mobile:

// apps/web/lib/api.ts
import { StockApiClient } from '@repo/api-client'
export const api = new StockApiClient(process.env.NEXT_PUBLIC_API_URL!)

// apps/mobile/lib/api.ts
import { StockApiClient } from '@repo/api-client'
import Constants from 'expo-constants'
export const api = new StockApiClient(Constants.expoConfig?.extra?.apiUrl)
```

**Shared UI Component with Tailwind:**
```typescript
// packages/ui/src/stock-card.tsx
import { Stock } from '@repo/types'
import { Button } from './button'
import { Card } from './card'

export function StockCard({ stock }: { stock: Stock }) {
  return (
    <Card className="p-4 bg-white dark:bg-gray-800 rounded-lg shadow">
      <h3 className="text-lg font-bold text-gray-900 dark:text-white">
        {stock.ticker}
      </h3>
      <p className="text-sm text-gray-600 dark:text-gray-400">{stock.name}</p>
      <p className={`text-xl font-semibold ${
        stock.change >= 0 ? 'text-bullish' : 'text-bearish'
      }`}>
        ${stock.price.toFixed(2)}
      </p>
      <Button>View Details</Button>
    </Card>
  )
}

// Works on both web (Tailwind) and mobile (NativeWind)!
```

**Shared Tailwind Config:**
```javascript
// packages/tailwind-config/index.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a'
        },
        bullish: {
          light: '#86efac',
          DEFAULT: '#10b981',
          dark: '#047857'
        },
        bearish: {
          light: '#fca5a5',
          DEFAULT: '#ef4444',
          dark: '#b91c1c'
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif']
      }
    }
  }
}

// Both platforms use same config:
// apps/web/tailwind.config.js
// apps/mobile/tailwind.config.js (NativeWind)
```

---

## 5. User Experience & Interface

### 5.1 Design Principles
- Clean, modern interface inspired by Bloomberg Terminal and Robinhood
- Data-dense but not overwhelming
- Mobile-responsive design
- Dark mode support (toggle)
- Fast loading with skeleton screens

### 5.2 Color Scheme
- **Primary**: Blue/Teal (trust, finance)
- **Success/Bullish**: Green shades
- **Warning/Bearish**: Red shades
- **Neutral**: Gray scale
- **Background**: White/Dark gray (mode dependent)

### 5.3 Navigation
- Top navbar: Logo, Search bar, Portfolio (paper trading), Watchlist, Profile dropdown
- Stock page: Header with stock info, Tab navigation, Content area, "Trade" button (prominent)
- Paper trading page: Portfolio selector dropdown, Performance summary cards, Holdings table, Charts
- Mobile: Hamburger menu, bottom tabs for main sections (Home, Portfolio, Watchlist, Profile)

### 5.4 Loading States
- **Suspense boundaries** for async components
- **Skeleton loaders** for charts and data tables
- **Loading.tsx files** in Next.js for route-level loading
- Progressive loading: Show cached data first, update with fresh data
- Loading indicators for tab switches
- Optimistic updates for user interactions

### 5.5 Error Handling
- **Error.tsx files** in Next.js for route-level error boundaries
- API error messages with retry options
- Rate limit warnings
- 404 pages for invalid tickers (not-found.tsx)
- Network error fallbacks
- Toast notifications for user actions

---

## 6. Implementation Phases

### Phase 1: MVP Setup & Web (Weeks 1-5)

**Monorepo Setup (Week 1)**
- Initialize Turborepo with PNPM workspaces
- Create apps/web, apps/mobile, apps/api structure
- Set up shared packages (types, api-client, ui, tailwind-config)
- Configure Turborepo pipeline
- Set up root scripts (dev, build, lint)

**Backend (Weeks 1-2)**
- Phoenix project setup in apps/api with PostgreSQL
- User authentication (email/password, JWT tokens)
- CORS configuration for both web and mobile
- Stock search and basic overview endpoint
- Integration with Alpha Vantage API
- Technical analysis endpoint with caching
- Basic Unusual Whales API integration (options flow, dark pool)

**Web Application (Weeks 2-4)**
- Next.js 14+ project setup in apps/web with TypeScript
- Tailwind CSS configuration (extends shared config)
- User authentication UI (login, register)
  - JWT token storage and management
  - Protected routes with middleware
- Stock search with autocomplete
- Stock overview page with technical analysis tab
- Basic charts (price + volume) with Lightweight Charts
- Institutional activity tab (basic options flow and dark pool sections)
- Import shared packages (@repo/api-client, @repo/types, @repo/ui)

**Mobile Application (Weeks 4-5)**
- React Native + Expo project setup in apps/mobile
- NativeWind (Tailwind for React Native) configuration
- Expo Router setup (file-based routing)
- User authentication screens (login, register)
  - JWT storage with SecureStore
- Basic tab navigation (Home, Portfolio, Watchlist)
- Stock search screen
- Stock detail screen (technical analysis)
- Import same shared packages as web

**Infrastructure (Week 5)**
- Phoenix deployed to Fly.io
- Next.js deployed to Vercel
- PostgreSQL on Fly.io
- Environment variables configured for all apps
- CORS and authentication flow tested on all platforms
- Expo dev build for testing on physical devices

**Deliverable**: 
- Monorepo working locally and deployed
- Users can register on web AND mobile
- Search stocks and view technical analysis on both platforms
- Shared code working across platforms
- Basic institutional activity visible

### Phase 2: Core Features (Weeks 6-10)
**Backend (Weeks 6-7)**
- Integration with Financial Modeling Prep API
- Fundamental analysis endpoint
- Reddit API integration (PRAW)
- Basic sentiment analysis engine
- Sentiment analysis endpoint
- Full Unusual Whales integration:
  - Congressional trading data
  - Insider trading data
  - Institutional holdings (13F filings)
  - Market tide indicator
  - Smart money score calculation
- Paper trading system:
  - Portfolio creation and management
  - Trade execution (market orders)
  - Holdings tracking
  - Transaction history
  - Performance calculation
- WebSocket support for real-time price updates

**Web Application (Weeks 6-8)**
- Fundamental analysis tab with server-rendered data
- Emotional analysis tab (with smart money section)
- Complete institutional activity tab
- Overall recommendation display (with institutional score)
- Watchlist functionality with optimistic updates
- Analysis history tracking
- Paper trading UI:
  - Portfolio dashboard (server + client components)
  - Trade modal from stock pages (client component)
  - Holdings view with real-time updates
  - Transaction history (server-rendered table)
  - Basic performance metrics and charts
- React Query setup for client-side data fetching
- Loading states and skeletons
- Error boundaries

**Mobile Application (Weeks 9-10)**
- All four analysis tabs (Technical, Fundamental, Emotional, Institutional)
- Overall recommendation view
- Watchlist with pull-to-refresh
- Paper trading:
  - Portfolio dashboard (native performance)
  - Trade modal (bottom sheet)
  - Holdings list with native animations
  - Transaction history
  - Performance charts (Victory Native)
- Push notifications setup (for price alerts - Phase 3)
- Biometric authentication (Face ID / Touch ID)
- Haptic feedback for trades
- Dark mode support

**Deliverable**: Full four-tab analysis system on web AND mobile + institutional insights + paper trading on both platforms

### Phase 3: Polish & Mobile Launch (Weeks 11-13)
**Backend (Week 11)**
- Shareable link generation with public access
- Friend invitation system (email)
- Background jobs for data refresh (Oban)
- Enhanced caching strategy with Redis
- Push notification infrastructure (Expo Push)

**Web Application (Week 11)**
- Share functionality with Open Graph previews
- Friend invitation UI
- User profile page
- Dark mode toggle with Next.js themes
- Mobile responsive improvements
- Image optimization for stock logos
- SEO optimization with metadata API
- Loading improvements (Suspense boundaries)

**Mobile Application (Weeks 12-13)**
- Push notifications:
  - Price alerts
  - Unusual whale activity alerts
  - Portfolio milestones
- Biometric authentication polish
- Haptic feedback refinement
- App icon and splash screen
- iOS screenshots and App Store assets
- Android screenshots and Play Store assets
- App Store Connect setup
- Google Play Console setup
- Privacy policy and terms of service pages
- In-app review prompts
- Crash reporting (Sentry)
- Analytics (Expo Analytics or Mixpanel)

**App Store Submission (Week 13)**
- iOS app review submission
- Android app review submission
- Beta testing with TestFlight (iOS) and Internal Testing (Android)
- Friend and family testing
- Bug fixes from testing feedback

**Deliverable**: 
- Fully polished web app
- Mobile apps live on App Store and Google Play
- Push notifications working
- Social features active on all platforms

### Phase 4: Enhancement (Weeks 14-16)
- Performance optimization (all platforms)
- Additional technical indicators
- News sentiment integration
- StockTwits integration
- Advanced charting features
- User feedback collection
- Institutional activity enhancements:
  - Real-time whale activity alerts (push notifications on mobile)
  - Historical options flow trends
  - Whale vs retail sentiment comparison
  - "Follow the Whales" paper trade suggestions
- Paper trading enhancements:
  - Performance charts and analytics
  - Portfolio composition visualizations
  - Recommendation tracking (accuracy of Strong Buy, etc.)
  - CSV export of transactions (web)
  - PDF report generation (web)
  - Multiple portfolio support
  - Friends leaderboard (opt-in)
- Mobile-specific:
  - Widgets (iOS 14+, Android 12+) for portfolio at-a-glance
  - Apple Watch complication (basic portfolio value)
  - Share sheet integration
  - Shortcuts support (iOS)

**Deliverable**: Production-ready v1.0 with polished paper trading, institutional insights, and native mobile experience on iOS and Android

**Total Timeline: 16 weeks (4 months)**

---

## 7. Risk Management & Mitigation

### 7.1 Technical Risks

**API Rate Limits**
- **Risk**: Exceeding free tier limits
- **Mitigation**: Aggressive caching, queue system for non-critical requests

**API Costs**
- **Risk**: Unexpected cost spikes with user growth
- **Mitigation**: Usage monitoring, rate limiting per user, circuit breakers

**Data Accuracy**
- **Risk**: Incorrect or outdated data leading to bad recommendations
- **Mitigation**: Multiple data source validation, clear disclaimers, data freshness indicators

**System Performance**
- **Risk**: Slow response times under load
- **Mitigation**: Database indexing, CDN for static assets, Phoenix horizontal scaling

**Paper Trading Data Integrity**
- **Risk**: Portfolio calculations becoming out of sync with transactions
- **Mitigation**: Database transactions, periodic reconciliation jobs, audit logs

**Price Data Consistency**
- **Risk**: Using stale prices for paper trades leading to unrealistic gains
- **Mitigation**: Clear timestamp on trades, use same 15-second cache as analysis, "executed at [time] at $X.XX price" confirmation

**Unusual Whales API Rate Limits**
- **Risk**: Exceeding API rate limits causing service disruption
- **Mitigation**: Aggressive caching (1-hour minimum), background job scheduling during off-peak, request queue with priority system, per-user rate limiting if needed, graceful degradation (show cached data with timestamp)

### 7.2 Legal & Compliance Risks

**Financial Advice Disclaimer**
- **Risk**: Liability for investment losses
- **Mitigation**: Prominent disclaimers, no personalized advice, educational framing

**Data Privacy**
- **Risk**: User data breaches
- **Mitigation**: Encrypted passwords, HTTPS, secure JWT tokens, GDPR compliance

**API Terms of Service**
- **Risk**: Violating API provider terms
- **Mitigation**: Careful review of ToS, respect rate limits, proper attribution

### 7.3 Business Risks

**User Acquisition**
- **Risk**: Low user adoption
- **Mitigation**: Beta testing with friends, Reddit/Discord community sharing, SEO optimization

**Competition**
- **Risk**: Established players (Yahoo Finance, TradingView)
- **Mitigation**: Focus on unique sentiment analysis feature, better UX, free tier

---

## 8. Success Criteria & KPIs

### 8.1 Launch Success (Month 1)
- 50+ registered users (combined web + mobile)
- 500+ stock analyses performed
- 200+ paper trades executed
- 30+ users with active paper portfolios
- 200+ institutional activity tab views
- 100+ mobile app downloads (iOS + Android combined)
- < 3 second average page load (web)
- < 2 second average screen load (mobile)
- < 5% error rate (all platforms)
- 5+ pieces of user feedback collected

### 8.2 Growth Metrics (Month 3)
- 200+ registered users
- 40% WAU retention
- Average 3+ stocks analyzed per session
- 60% of active users have made at least 1 paper trade
- Average 5 trades per active paper trading user
- 70%+ users view institutional activity tab
- 10+ shares to non-users
- Net Promoter Score (NPS) > 30
- Mobile app metrics:
  - 30%+ of users are mobile-primary
  - 4.0+ star rating on App Store and Google Play
  - < 2% crash rate
  - 50+ push notification opt-ins

### 8.3 Technical Metrics
- API response time: p95 < 500ms
- Web page rendering: p95 < 2s
- Mobile screen rendering: p95 < 1.5s
- Uptime: 99%+
- Cache hit rate: > 60%
- Unusual Whales API: < 80% of rate limit used

### 8.4 Paper Trading Specific Metrics
- Portfolio creation rate: 50%+ of registered users
- Trade execution success rate: 99%+
- Average portfolio value change: Track correlation with actual market
- Recommendation accuracy: % of "Strong Buy" recommendations that gain value in paper portfolios
- Engagement: Users with paper portfolios have 2-3x session frequency

### 8.5 Institutional Activity Metrics
- Tab view rate: 70%+ of users who view a stock
- Unusual Whales data freshness: Average age < 2 hours
- Smart money score accuracy: Track correlation between high scores and price movement
- User engagement: Average time on institutional tab > 2 minutes

### 8.6 Mobile App Metrics
- Daily Active Users (DAU)
- Session length: Average > 5 minutes
- Push notification delivery rate: > 95%
- Push notification click-through rate: > 10%
- Crash-free sessions: > 98%
- App launch time: < 2 seconds (cold start)
- OTA update adoption: > 80% within 7 days

---

## 9. Disclaimer & Legal

### 9.1 Investment Disclaimer
**Required on every page:**
"This platform is for informational and educational purposes only. The analysis and recommendations provided are not financial advice. Always conduct your own research and consult with a qualified financial advisor before making investment decisions. Past performance does not guarantee future results."

**Paper Trading Specific Disclaimer:**
"Paper trading uses simulated money and simulated trades. Results from paper trading do not represent actual trading results and may not reflect the impact of commissions, slippage, or emotional factors in real trading. Paper trading performance is not indicative of future real trading results."

### 9.2 Data Attribution
"Stock data provided by Alpha Vantage, Financial Modeling Prep, and other third-party sources. Social sentiment data aggregated from Reddit and other public platforms. Institutional activity data, options flow, dark pool data, congressional trading, and insider trading information provided by Unusual Whales. Unusual Whales data is for informational purposes only and does not constitute investment advice."

---

## 10. Future Enhancements (Post-MVP)

### 10.1 Advanced Features
- Portfolio tracking and performance analysis (real money, not just paper)
- Backtesting recommendations against historical data
- Alerts and notifications (price targets, sentiment changes)
- Options analysis
- Cryptocurrency support
- Comparison tool (compare 2-5 stocks side-by-side)
- Paper trading advanced features:
  - Options paper trading
  - Limit and stop-loss orders
  - Short selling
  - Margin trading simulation
  - Risk analytics (beta, Sharpe ratio, max drawdown)
  - AI portfolio advisor
  - Tournament mode (compete with friends in time-limited challenges)
  - Paper trading education courses
- Institutional activity advanced features:
  - Real-time options flow streaming
  - Custom whale alerts (threshold-based)
  - Historical correlation analysis (whale activity vs price)
  - Whale portfolio replication
  - Gamma exposure analysis
  - Max pain calculator
  - Options chain heatmaps
  - Institution-specific tracking (follow specific hedge funds)

### 10.2 Monetization (Optional)
- Premium tier: Unlimited analyses, advanced indicators, real-time data, enhanced institutional insights (real-time whale alerts, custom thresholds, historical correlations)
- API access for developers
- White-label solution for financial advisors
- Affiliate partnerships with brokerages

### 10.3 AI Enhancements
- AI-powered stock insights and summaries
- Natural language queries ("Find undervalued tech stocks with positive sentiment")
- Predictive modeling for price movements

---

## 11. Development Resources

### 11.1 Team Structure (Recommended)
- **Developer (You)**: Full-stack development
- **Feedback Providers**: 5-10 friends for beta testing

### 11.2 Tools & Services
- **Version Control**: GitHub (monorepo)
- **Monorepo Tool**: Turborepo
- **Package Manager**: PNPM
- **Web Hosting**: Vercel (Next.js)
  - Automatic deployments on git push
  - Preview deployments for PRs
  - Custom domain with SSL
  - Environment variable management
  - Analytics included
- **Backend Hosting**: Fly.io (Phoenix + PostgreSQL)
  - Easy Phoenix deployment
  - Managed PostgreSQL
  - SSL certificates
  - Global CDN
- **Mobile Build & Deploy**: Expo Application Services (EAS)
  - Cloud builds for iOS and Android
  - TestFlight and Google Play beta distribution
  - Over-the-air updates
  - Push notification infrastructure
- **App Store Accounts**:
  - Apple Developer Program ($99/year)
  - Google Play Developer ($25 one-time)
- **CI/CD**: 
  - Vercel for Next.js (automatic)
  - GitHub Actions for Phoenix tests
  - EAS Build for mobile apps
- **Monitoring**: 
  - Vercel Analytics (web)
  - Sentry for error tracking (all platforms)
  - Phoenix LiveDashboard (backend)
  - Expo Error Reporting (mobile)
- **Analytics**: 
  - Plausible or Umami (web - privacy-focused)
  - Expo Analytics or Mixpanel (mobile)
- **Communication**: Discord server for beta users

### 11.3 Documentation
- API documentation (OpenAPI/Swagger)
- User guide for features
- Developer setup guide (README)

### 11.4 Development Workflow

**Initial Setup:**

1. **Clone monorepo:**
```bash
git clone https://github.com/yourusername/stock-analysis
cd stock-analysis
pnpm install  # Installs all dependencies for all apps/packages
```

2. **Environment configuration:**
```bash
# Backend: apps/api/config/dev.exs
config :stock_analysis, StockAnalysisWeb.Endpoint,
  http: [port: 4000],
  url: [host: "localhost"]

# Web: apps/web/.env.local
NEXT_PUBLIC_API_URL=http://localhost:4000

# Mobile: apps/mobile/.env
EXPO_PUBLIC_API_URL=http://localhost:4000
# Or use your machine's local IP for testing on physical device
# EXPO_PUBLIC_API_URL=http://192.168.1.100:4000
```

3. **Run everything:**
```bash
# Terminal 1: Phoenix backend
cd apps/api
mix phx.server
# Runs on http://localhost:4000

# Terminal 2: All frontend apps (web + mobile)
pnpm dev
# Web on http://localhost:3000
# Mobile: Expo dev server starts, scan QR with Expo Go app
```

**Monorepo Commands:**

```bash
# Run all apps
pnpm dev

# Run specific app
pnpm dev --filter=web
pnpm dev --filter=mobile
pnpm dev --filter=api

# Build all apps
pnpm build

# Build specific app
pnpm build --filter=web
pnpm build --filter=mobile

# Lint everything
pnpm lint

# Type check everything
pnpm type-check

# Clean everything
pnpm clean

# Add dependency to specific app
cd apps/web && pnpm add react-query
cd apps/mobile && pnpm add expo-notifications

# Add dependency to shared package
cd packages/ui && pnpm add clsx
```

**Mobile Development:**

```bash
# Start Expo dev server
cd apps/mobile
pnpm start

# Run on iOS simulator (requires Mac)
pnpm ios

# Run on Android emulator
pnpm android

# Run on physical device
# 1. Install Expo Go app on your phone
# 2. Scan QR code from pnpm start
# 3. App runs on device

# Create development build (required for native modules)
eas build --profile development --platform ios
eas build --profile development --platform android

# Install development build on device
eas build:run --profile development --platform ios
```

**Development Features:**
- Hot reload on all platforms (web, iOS, Android)
- TypeScript type checking across entire monorepo
- Shared types kept in sync automatically
- Phoenix LiveDashboard at `/dashboard`
- Next.js Fast Refresh
- Expo Fast Refresh
- Tailwind CSS IntelliSense works for both web and mobile

**Deployment Workflow:**

**1. Backend (Phoenix to Fly.io):**
```bash
cd apps/api
fly launch
fly postgres create
fly secrets set SECRET_KEY_BASE=xxx
fly secrets set UNUSUAL_WHALES_API_KEY=xxx
fly deploy
```

**2. Web (Next.js to Vercel):**
```bash
# One-time setup
cd apps/web
vercel link

# Set environment variables in Vercel dashboard
NEXT_PUBLIC_API_URL=https://your-api.fly.dev

# Deploy (or push to GitHub for auto-deploy)
vercel --prod
```

**3. Mobile (React Native to App Stores via EAS):**
```bash
cd apps/mobile

# Build for production
eas build --platform ios --profile production
eas build --platform android --profile production

# Submit to stores
eas submit --platform ios
eas submit --platform android

# Or auto-submit after build
eas build --platform all --profile production --auto-submit
```

**Over-the-Air Updates (Mobile):**
```bash
# Update mobile app without app store review
cd apps/mobile
eas update --branch production --message "Fix minor bug"

# Users get update next time they open app
```

**Environment Variables Management:**

**Development:**
- Backend: `apps/api/config/dev.exs`
- Web: `apps/web/.env.local`
- Mobile: `apps/mobile/.env`

**Production:**
- Backend: Fly.io secrets
- Web: Vercel dashboard
- Mobile: EAS Secrets (`eas secret:create`)

**Testing Strategy:**

**Backend (Phoenix):**
```bash
cd apps/api
mix test
mix test --cover
```

**Web (Next.js):**
```bash
cd apps/web
pnpm test              # Jest + React Testing Library
pnpm test:e2e         # Playwright
pnpm type-check
pnpm lint
```

**Mobile (React Native):**
```bash
cd apps/mobile
pnpm test             # Jest + React Native Testing Library
pnpm type-check
pnpm lint

# E2E testing with Detox (optional)
pnpm test:e2e:ios
pnpm test:e2e:android
```

**Shared Packages:**
```bash
cd packages/api-client
pnpm test
pnpm build

cd packages/ui
pnpm test
pnpm build
```

---

## 12. Appendix

### 12.1 Glossary
- **RSI**: Relative Strength Index - momentum indicator
- **MACD**: Moving Average Convergence Divergence
- **P/E Ratio**: Price-to-Earnings ratio
- **Sentiment Score**: Aggregated emotional tone from social media
- **Technical Analysis**: Stock evaluation using price/volume patterns
- **Fundamental Analysis**: Stock evaluation using financial metrics
- **Paper Trading**: Simulated trading with virtual money for practice
- **Market Order**: Buy/sell order executed immediately at current market price
- **Limit Order**: Order that executes only at specified price or better
- **Stop-Loss**: Order that automatically sells when price drops to specified level
- **Holdings**: Stocks currently owned in a portfolio
- **Unrealized Gain/Loss**: Profit/loss on holdings not yet sold
- **Realized Gain/Loss**: Profit/loss from completed trades
- **Cost Basis**: Average price paid per share for a holding
- **Portfolio Value**: Total worth of all holdings plus cash
- **Options Flow**: Large unusual options trades that may indicate institutional positioning
- **Dark Pool**: Private exchange for large block trades away from public markets
- **Put/Call Ratio**: Ratio of put option volume to call option volume, sentiment indicator
- **Whale**: Large institutional investor or trader making significant trades
- **13F Filing**: Quarterly report showing institutional holdings (required for funds >$100M)
- **Insider Trading**: Legal trades by corporate executives in their own company stock
- **Congressional Trading**: Stock trades disclosed by members of Congress
- **Block Trade**: Single trade of at least 10,000 shares or $200K in value
- **Smart Money**: Institutional investors and professional traders
- **Premium**: Total dollar amount paid for options contracts

### 12.2 Useful Resources
- **APIs**:
  - Alpha Vantage Docs: https://www.alphavantage.co/documentation/
  - Financial Modeling Prep Docs: https://site.financialmodelingprep.com/developer/docs
  - PRAW Docs: https://praw.readthedocs.io/
  - Unusual Whales API Docs: https://api.unusualwhales.com/docs
- **Frontend**:
  - Next.js Docs: https://nextjs.org/docs
  - Next.js App Router: https://nextjs.org/docs/app
  - React Documentation: https://react.dev
  - Tailwind CSS: https://tailwindcss.com/docs
  - Shadcn/ui Components: https://ui.shadcn.com
- **Backend**:
  - Phoenix Guides: https://hexdocs.pm/phoenix/overview.html
  - Phoenix Authentication: https://hexdocs.pm/phoenix/authentication.html
  - Ecto Documentation: https://hexdocs.pm/ecto/Ecto.html
- **Deployment**:
  - Vercel Docs: https://vercel.com/docs
  - Fly.io Docs: https://fly.io/docs
- **Learning Resources**:
  - Next.js Learn: https://nextjs.org/learn
  - Elixir School: https://elixirschool.com
  - Phoenix Deployment Guide: https://hexdocs.pm/phoenix/deployment.html

---

**Document Version**: 3.0 (Monorepo + Mobile Edition)  
**Last Updated**: February 24, 2026  
**Architecture**: Turborepo Monorepo  
**Web**: Next.js 14+ with App Router  
**Mobile**: React Native + Expo with NativeWind  
**Backend**: Elixir Phoenix 1.7+  
**Styling**: Tailwind CSS (web) + NativeWind (mobile)  
**Total Timeline**: 16 weeks  
**Next Review**: After Phase 1 completion