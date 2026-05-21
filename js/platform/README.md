# @pixelcrafts/platform

PixelCrafts Platform SDK — copy-paste module for web apps.

## Setup

1. Copy this folder into your app:
   ```
   cp -r pixelcrafts-sdk/js/platform ./lib/pixelcrafts-sdk
   ```

2. Import and initialize once:
   ```ts
   import { PixelCraftsPlatform } from "@/lib/pixelcrafts-sdk";

   PixelCraftsPlatform.init({
     appId: "themeroid",
     apiKey: process.env.NEXT_PUBLIC_PC_API_KEY!,
     baseUrl: "https://auth.pixelcrafts.app/v1",
     tokenProvider: async () => localStorage.getItem("pc_token"),
     onSessionExpired: () => {
       localStorage.removeItem("pc_token");
       window.location.href = "/login";
     },
   });
   ```

## Usage

```ts
// Billing
const status = await PixelCraftsPlatform.billing.getStatus();
const plans  = await PixelCraftsPlatform.billing.getPlans();

// Support
const ticket = await PixelCraftsPlatform.support.createTicket({
  subject: "Something is broken",
  message: "...",
});

// Sync
const state = await PixelCraftsPlatform.sync.getStatus();
await PixelCraftsPlatform.sync.push({ achievements: [1, 2] });

// Legal
const docs = await PixelCraftsPlatform.legal.getDocuments();
await PixelCraftsPlatform.legal.accept("privacy_policy", "2.0");
```

## API Surface

- `PixelCraftsPlatform.auth` — sync, getMe, logout, reactivate, getSettings, updateSettings, deleteAccount, exportData
- `PixelCraftsPlatform.billing` — getStatus, getPlans, getEntitlements
- `PixelCraftsPlatform.support` — createTicket, getTickets, getTicket, addMessage, closeTicket
- `PixelCraftsPlatform.sync` — getStatus, push, pull, getAllData, getDataKey, putDataKey, patchDataKey, deleteDataKey
- `PixelCraftsPlatform.legal` — getDocuments, getDocument, accept, getAcceptanceStatus
- `PixelCraftsPlatform.push` — registerDevice, unregisterDevice, getPreferences, updatePreferences
