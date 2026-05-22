# Broker Dashboard - FutureTrust Real Estate OS

A premium, secure, dataless broker business vault dashboard for The Sourcing Manager OS.

## Features

- **Dataless Constitution**: Never exposes phone numbers or sensitive contact data
- **Premium Hi-Tech Theme**: Dark charcoal background with glowing accents
- **Mobile-First Design**: Optimized for one-hand usage on the street
- **Secure Lead Management**: Alias-based lead tracking with protected actions
- **Real-Time KPI Ribbon**: Horizontally scrollable metrics dashboard
- **Broker Identity Card**: Verified broker profile with trust indicators
- **Growth Insights**: AI-powered business coaching tips
- **Action Menus**: Bottom sheet on mobile, popover on desktop

## Tech Stack

- **Framework**: Next.js 15 with App Router
- **Styling**: Tailwind CSS
- **Animations**: Framer Motion
- **Icons**: Lucide React
- **Language**: TypeScript

## Getting Started

1. Install dependencies:

   ```bash
   npm install
   ```

2. Run the development server:

   ```bash
   npm run dev
   ```

3. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
src/
├── app/
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
└── components/
    ├── BrokerDashboardFutureTrust.tsx
    ├── StickyTrustHeader.tsx
    ├── KpiRibbon.tsx
    ├── KpiCard.tsx
    ├── BrokerIdentityCard.tsx
    ├── GrowthInsightCard.tsx
    ├── SecureLeadCard.tsx
    ├── StatusPill.tsx
    └── LeadActionBottomSheet.tsx
```

## Security & Privacy

This dashboard adheres to strict dataless principles:

- No phone numbers displayed
- No raw customer names
- No contact export functionality
- All actions through secure backend bridges
- Alias-based lead identification

## Mock Data

The dashboard uses safe mock data for demonstration:

- Lead aliases (L-1042, etc.)
- Safe project and area names
- Budget ranges
- Status indicators

## Deployment

Build for production:

```bash
npm run build
```

The production build is optimized for web deployment and can be integrated with the Flutter app or deployed separately.

## License

AGPL-3.0-only
