# LikeALocal — Feature Documentation

Every feature implemented, what it does, and exactly how to test it in the running app.

---

## Onboarding & Auth

### F2 — Splash Screen Animation
**What it does:** An animated splash screen plays on cold start. The logo fades in and scales up with an elastic bounce, while the tagline slides up from below. After 2.2 seconds it auto-navigates based on state.

**How to test:**
1. Cold-launch the app (or kill and reopen it)
2. Watch the logo animate in with a bounce effect
3. App navigates automatically — to Onboarding on first launch, to Feed if already logged in

---

### F1 — Onboarding Slides (shown once)
**What it does:** Three full-screen onboarding slides introduce the app on first launch only. Animated dot indicators show current position. Skip jumps to the end. After finishing, the flag is saved and onboarding never shows again.

**How to test:**
1. First launch (or clear app data): onboarding appears automatically after splash
2. Swipe through all 3 slides — dots animate width/opacity
3. Tap "Skip" on slide 1 or 2 — jumps to last slide
4. Tap "Get Started" — navigates to Login
5. Kill and reopen the app — onboarding does NOT show again

---

### F3 — Password Eye Toggle
**What it does:** A visibility icon in the password field lets users show/hide their password while typing.

**How to test:**
1. Go to Login screen
2. Type anything in the Password field
3. Tap the eye icon on the right — text reveals
4. Tap again — text hides

---

### F5 — Real-time Form Validation
**What it does:** As you type in the login/register form, each field shows a green checkmark (valid) or red X (invalid) in real time, without waiting for submit.

**How to test:**
1. Go to Login screen
2. Type an invalid email (e.g. "abc") — red X appears
3. Type a valid email (e.g. "a@b.com") — green check appears
4. Type a short password (< 6 chars) — red X appears
5. Type a valid password — green check appears

---

### F6 — Remember Me
**What it does:** A "Remember me" checkbox on the login screen saves your email to local storage. Next time you open the login screen, the email is pre-filled.

**How to test:**
1. Go to Login screen
2. Type your email, check the "Remember me" checkbox
3. Log in successfully
4. Log out, go back to Login
5. Your email is already filled in the email field

---

### F7 — Account Deletion
**What it does:** In Settings > Account, a "Delete Account" option opens a confirmation dialog that requires typing the word "DELETE" before proceeding. Deletes the Firestore user document and Firebase Auth account.

**How to test:**
1. Go to Settings → scroll to Account section → tap "Delete Account"
2. Dialog opens — the Delete button is disabled initially
3. Type anything other than "DELETE" — button stays disabled
4. Type exactly "DELETE" — button becomes enabled (red)
5. Tap Delete — account is deleted, app redirects to login

---

## Feed

### F13 — Skeleton Shimmer Loading
**What it does:** While the feed is loading from Firestore, animated shimmer placeholders appear in the shape of post cards instead of a blank screen.

**How to test:**
1. Open the app on a slow connection, or kill and reopen
2. While the Feed tab is loading, you see 4 grey shimmer card shapes pulsing with a white highlight sweep

---

### F14 — Empty Feed State
**What it does:** If no posts exist in the database, the feed shows a friendly illustration and a direct "Add a Place" button instead of a blank white screen.

**How to test:**
1. Only testable with a fresh/empty Firestore database
2. The screen shows an orange explore icon in a circle, "No posts yet!", and an "Add a Place" button
3. Tapping the button navigates directly to the Create Post screen

---

### F8 — Pull-to-Refresh with Haptic
**What it does:** Pull down on the feed to refresh posts. The spinner is orange (matching brand color) and a light haptic pulse fires on trigger.

**How to test:**
1. On the Feed screen, pull down from the top
2. Feel a light vibration as the refresh triggers
3. Orange spinner appears, new posts load

---

### F16 — Infinite Scroll Pagination
**What it does:** The feed loads 10 posts at a time. When you scroll within 300px of the bottom, the next page loads automatically. A spinner shows while loading more, and "You've seen everything!" appears when the list is exhausted.

**How to test:**
1. With 10+ posts in the database, scroll to the bottom of the feed
2. A small orange spinner appears at the bottom
3. More posts load and append to the list
4. When no more posts exist, "You've seen everything!" text appears

---

### F15 — Double-Tap to Upvote (Heart Animation)
**What it does:** Double-tapping anywhere on a post card triggers an upvote. A large heart icon animates — scaling up with elastic bounce and fading out — over the card. The haptic feedback fires on each double tap.

**How to test:**
1. Open the Feed screen
2. Double-tap on any post card
3. A heart icon animates in the center of the card (scale + fade)
4. The upvote count increments
5. Haptic medium-impact fires on each double tap

---

### F17 — Category Color Chips
**What it does:** Each post card shows a small colored pill badge next to the post type. Colors are semantic: Restaurant=orange, Bar=purple, Café=brown, Park=green, Viewpoint=blue, Shop=pink.

**How to test:**
1. Browse the Feed
2. Look at the top-left of each post card — a colored pill shows the category
3. Restaurant posts have orange chips, Parks have green, etc.

---

### F11 — Share Post
**What it does:** Each post card has a share button (arrow icon) that triggers the native OS share sheet with the post title and location.

**How to test:**
1. Open the Feed
2. Tap the share icon (arrow pointing up/right) on any post card
3. The native Android share sheet appears with the post title and location text
4. You can share to any app (WhatsApp, clipboard, etc.)

---

### F46 — Haptic Feedback
**What it does:** Haptic vibrations fire on key interactions throughout the app for a polished, physical feel.

**How to test:**
- Light haptic: pull-to-refresh trigger, save/bookmark tap
- Medium haptic: upvote tap, double-tap to upvote

---

### F51 — Error Retry Button
**What it does:** If the feed fails to load (network error, Firestore error), instead of a dead screen, an error widget appears with a "Try Again" button that retriggers the load.

**How to test:**
1. Disable internet on the device before opening the Feed
2. You see a cloud-off icon, error message, and "Try Again" button
3. Re-enable internet, tap "Try Again" — feed loads

---

## Post Detail & Creation

### F9 — Full-Screen Image Zoom
**What it does:** Tapping a post's image opens a full-screen viewer. You can pinch to zoom up to 3×, and double-tap to zoom in at that point (or reset if already zoomed). Hero animation transitions from card to full-screen smoothly.

**How to test:**
1. Open any post with an image
2. Tap the image — it Hero-animates into a dark full-screen viewer
3. Pinch to zoom in/out
4. Double-tap on a spot — zooms to 3× centered on that spot
5. Double-tap again — resets to fit-screen
6. Tap the back button or swipe back to return

---

### F22 — Draft Auto-Save on Create Post
**What it does:** As you type in the Create Post form (title, description, location), the content is automatically saved to SharedPreferences every time you stop typing. If you leave mid-way and come back, the draft is restored with a snackbar offering a "Discard" option.

**How to test:**
1. Go to Create Post
2. Type a title, description, and location
3. Navigate away (tap the back button or switch tabs) without submitting
4. Come back to Create Post
5. Your text is pre-filled, and a snackbar appears: "Draft restored" with a "Discard" action
6. Tap "Discard" — fields clear

---

### F23 — Character Counter on Caption
**What it does:** The description field in Create Post shows a live character counter (e.g. "120/500"). When you exceed 500 characters, the counter turns red.

**How to test:**
1. Go to Create Post
2. Type in the Description field
3. A counter appears below the field: "X/500"
4. Type more than 500 characters — the counter turns red

---

### F18 — Image Compression Before Upload
**What it does:** When you pick an image for a post, it is compressed to 72% JPEG quality and capped at 1080px height before uploading. The snackbar shows the resulting file size. Images over 4MB are rejected.

**How to test:**
1. Go to Create Post → tap the image area
2. Pick a large photo from your gallery
3. A snackbar shows the compressed size in KB (e.g. "Image selected: 340 KB")
4. Try picking an image over 4MB — you get an "Image too large" snackbar

---

### F52 — Keyboard Avoidance
**What it does:** Text input fields on the Create Post and Login screens are never hidden by the keyboard. The view scrolls up automatically when a field is focused.

**How to test:**
1. Go to Create Post
2. Tap the Description field (near the bottom of the form)
3. The keyboard appears and the view scrolls up so the field stays visible
4. Same behavior on the Login screen password field

---

## Map

### F26 — Pulsing Location Dot
**What it does:** When location tracking is active, your position is shown as a pulsing blue dot (like iOS Maps). The outer ring animates in opacity and size to confirm live GPS.

**How to test:**
1. Go to the Map tab
2. Tap the orange location button (top-right, next to the search bar)
3. Grant location permission if prompted
4. A blue pulsing dot appears at your current position on the map

---

### F29 — Distance Badges on Map Pins
**What it does:** When your location is active, each place pin on the map shows a small white label below it with the distance from you (e.g. "0.3 km" or "450 m").

**How to test:**
1. Enable location on the map (tap the location button)
2. Zoom out — each orange pin shows a small distance badge below it
3. The distances update as you move

---

### F30 — Filter by Distance Slider
**What it does:** A distance filter button (right sidebar) opens a bottom sheet with a slider (0.5–20 km). Setting it hides all pins farther than the selected distance. The button turns orange when a filter is active.

**How to test:**
1. Enable location on the map
2. Tap the ruler/distance icon on the right side of the map
3. Bottom sheet opens with a slider
4. Drag the slider to 2 km → tap "Apply Filter"
5. Pins farther than 2 km disappear
6. The distance button turns orange
7. Tap again → tap "Clear" → all pins return

---

### F25 — Marker Clustering
**What it does:** When zoomed out, nearby pins automatically merge into an orange circle showing the count (e.g. "7"). As you zoom in, clusters split back into individual pins.

**How to test:**
1. Go to the Map tab (with posts in the database)
2. Zoom all the way out using the minus button or pinch
3. Nearby pins collapse into orange circle badges with a number
4. Zoom back in — clusters split into individual pins

---

### F27 — Map Style Toggle (Light/Dark)
**What it does:** A sun/moon icon button on the right side of the map switches between the light Stadia map tiles and the dark Stadia map tiles. The preference is saved and restored on next launch.

**How to test:**
1. Go to the Map tab — map is in light mode by default
2. Tap the moon icon (bottom of right-side buttons)
3. Map switches to a dark/grey tile style
4. Tap the sun icon — switches back to light
5. Kill and reopen app, go to Map — your last preference is remembered

---

## Chat & AI

### F36 — AI Quick-Reply Chips
**What it does:** In the AI chat screen, a horizontal row of suggestion chips appears above the input bar: "Tell me more", "Any alternatives?", "How to get there?", etc. Tapping a chip fills the input field with that text.

**How to test:**
1. Go to the Chat tab → tap the AI assistant conversation
2. Above the input bar, you see purple suggestion chips
3. Tap "Tell me more" — the input fills with that text
4. Edit if needed, then send

---

### F37 — AI Message Formatting (Markdown)
**What it does:** The AI assistant's responses are rendered as rich markdown — bold text, bullet lists, and headers display properly instead of showing raw `**text**` syntax.

**How to test:**
1. Open the AI chat
2. Ask something like "Give me a list of the best cafes in Cairo"
3. The response renders with styled bullet points, bold headings, and proper spacing

---

### F32 — Read Receipts (Single / Double Tick)
**What it does:** In direct message chats, each message you send shows a tick below the bubble:
- **Single grey tick** = message sent and stored
- **Double blue tick** = the other person has opened the chat and read it

**How to test:**
1. Log in as User A on one device/emulator
2. Log in as User B on a second device/account
3. User A opens a DM chat with User B and sends a message
4. User A sees a single grey tick below the bubble
5. User B opens the same chat
6. User A's bubble now shows a double blue tick

---

## Settings & Personalization

### F43 — Dark Mode (Light / System / Dark)
**What it does:** Settings > Appearance has a 3-segment control: Light, System, Dark. It controls the entire app's theme. The choice is persisted across launches.

**How to test:**
1. Go to Settings → Appearance section
2. Tap "Dark" — the entire app switches to dark mode (scaffold, cards, inputs, buttons)
3. Tap "System" — app follows the device's system theme
4. Tap "Light" — app returns to light mode
5. Kill and reopen — your preference is applied immediately from splash

---

## Notifications

### F53 — Unread Badge Count on Notification Bell
**What it does:** The bell icon in the top bar shows a red badge with the count of unread notifications. The count streams live from Firestore and updates in real time.

**How to test:**
1. Trigger an activity that creates a notification (another user upvotes your post, for example)
2. Look at the top bar bell icon — a red circle with a number appears
3. Tap the bell → go to Notifications screen
4. Read/tap a notification
5. Return to the main screen — the badge count decreases

---

## Connectivity

### F48 — Offline Banner
**What it does:** When the device loses internet connectivity, a yellow "You are offline — showing cached content" banner appears at the top of the app. It disappears automatically when connectivity is restored.

**How to test:**
1. Use the app normally on Feed
2. Turn on Airplane Mode (or disable Wi-Fi and mobile data)
3. A yellow banner appears: "You are offline — showing cached content"
4. Re-enable internet — banner dismisses automatically

---

## Summary Table

| Feature | Category | Location in App |
|---|---|---|
| F1 — Onboarding slides | Onboarding | First launch after splash |
| F2 — Splash animation | Onboarding | App cold start |
| F3 — Password eye toggle | Auth | Login screen |
| F5 — Real-time form validation | Auth | Login screen |
| F6 — Remember Me | Auth | Login screen → checkbox |
| F7 — Account deletion | Settings | Settings → Account |
| F8 — Pull-to-refresh + haptic | Feed | Feed tab, pull down |
| F9 — Pinch/double-tap image zoom | Post Detail | Post image → tap |
| F11 — Share post | Feed | Post card share icon |
| F13 — Shimmer loading | Feed | Feed tab on load |
| F14 — Empty feed state | Feed | Feed tab (empty DB) |
| F15 — Double-tap to upvote | Feed | Post card double-tap |
| F16 — Infinite scroll pagination | Feed | Scroll to bottom of feed |
| F17 — Category color chips | Feed | Post card top-left pill |
| F18 — Image compression | Create Post | Image picker |
| F22 — Draft auto-save | Create Post | Leave mid-edit, return |
| F23 — Character counter | Create Post | Description field |
| F25 — Marker clustering | Map | Map tab, zoom out |
| F26 — Pulsing location dot | Map | Map tab, enable location |
| F27 — Map style toggle | Map | Map right-side moon button |
| F29 — Distance badges on pins | Map | Map tab + location on |
| F30 — Distance filter slider | Map | Map right-side ruler icon |
| F32 — Read receipts | Chat | DM conversation screen |
| F36 — AI suggestion chips | Chat | AI chat, above input |
| F37 — AI markdown formatting | Chat | AI chat message bubbles |
| F43 — Dark mode toggle | Settings | Settings → Appearance |
| F46 — Haptic feedback | Feed/Map | Double-tap, upvote, save |
| F48 — Offline banner | Global | Top of app |
| F51 — Error retry button | Feed | Feed on network failure |
| F52 — Keyboard avoidance | Create/Login | Text fields on mobile |
| F53 — Unread notification badge | Global | Top bar bell icon |
