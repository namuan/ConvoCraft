# ConvoCraft Permissions Guide

## Overview
ConvoCraft now includes a comprehensive onboarding flow that requests and verifies all necessary permissions before you can start recording meetings.

## Required Permissions

### 1. **Speech Recognition** 🎙️
- **Purpose**: Enables real-time transcription of meeting audio
- **How it's used**: Converts spoken words into text
- **macOS Setting**: System Settings > Privacy & Security > Speech Recognition

### 2. **Microphone Access** 🎤
- **Purpose**: Captures audio from your microphone
- **How it's used**: Records your voice and meeting participants
- **macOS Setting**: System Settings > Privacy & Security > Microphone

### 3. **Siri & Dictation** 🔊
- **Purpose**: Provides the underlying speech recognition engine
- **How it's used**: Powers the transcription service
- **macOS Setting**: System Settings > Siri & Spotlight > Enable "Dictation"
- **Note**: This MUST be enabled for speech recognition to work

### 4. **Screen Recording** 📺
- **Purpose**: Allows capturing system audio (required by ScreenCaptureKit)
- **How it's used**: Records audio from video conferencing apps like Zoom, Teams, etc.
- **macOS Setting**: System Settings > Privacy & Security > Screen Recording
- **Note**: This is the macOS requirement for audio capture, even though we're only capturing audio, not video

## Onboarding Flow

### First Launch
When you first launch ConvoCraft, you'll see an onboarding screen that:

1. **Explains each permission** with clear descriptions
2. **Shows permission status** with checkmarks when granted
3. **Guides you to System Settings** if permissions are denied
4. **Prevents app usage** until all permissions are granted

### Permission Request Process

1. Click "Grant Permissions" button
2. macOS will show permission dialogs for:
   - Speech Recognition (approve immediately)
   - Microphone (approve immediately)
   - Siri & Dictation (requires System Settings - see below)
   - Screen Recording (requires System Settings)

3. For Siri & Dictation:
   - Click "Open System Settings" when prompted
   - Go to **Siri & Spotlight**
   - Enable **"Dictation"**
   - Click "Check Again" in ConvoCraft to verify

4. For Screen Recording:
   - If the first attempt fails, you'll see an alert
   - Click "Open System Settings" to go directly to the right panel
   - Enable "ConvoCraft" in the Screen Recording list
   - Restart the app

### Resetting Onboarding
If you need to see the onboarding screen again:

```bash
defaults delete com.convocraft.app onboardingComplete
```

Then restart the app.

## Troubleshooting

### "Siri and Dictation are disabled" Error
This is a critical requirement. To fix:

1. Open **System Settings**
2. Navigate to **Siri & Spotlight** (or **Siri & Dictation** on older macOS)
3. Enable **"Dictation"** toggle
4. **Restart ConvoCraft**
5. All other permissions must also be granted

### "Screen Recording Permission Required" Error
This is the most common issue. To fix:

1. Open **System Settings**
2. Navigate to **Privacy & Security** > **Screen Recording**
3. Find **ConvoCraft** in the list
4. Toggle it ON
5. **Restart ConvoCraft**

### Permissions Not Working
If permissions still don't work after granting:

1. Reset all permissions for ConvoCraft:
   ```bash
   tccutil reset All com.convocraft.app
   ```

2. Delete the app and reinstall:
   ```bash
   rm -rf ~/Applications/ConvoCraft.app
   ./install.command --open
   ```

### Permission Status Check
You can verify permissions are granted by checking:
- All three checkmarks are green in the onboarding screen
- The "Get Started" button is enabled

## Why These Permissions?

**Speech Recognition + Microphone** enable audio capture and transcription.

**Siri & Dictation** is the underlying macOS service that powers speech recognition:
- Required by the Speech Recognition framework
- Must be enabled in System Settings
- Without it, speech recognition will fail with "Siri and Dictation are disabled"
- No audio will be transcribed even if other permissions are granted

**Screen Recording** permission might seem odd for an audio app, but:
- macOS requires this permission for ScreenCaptureKit
- ScreenCaptureKit is the modern API for capturing system audio
- We only capture audio, never video
- This allows capturing audio from video conferencing apps

## Technical Details

### Permission Verification Flow
1. On app launch, check if onboarding is complete
2. If not, show onboarding screen
3. Check current status of all three permissions
4. Request missing permissions
5. Verify all permissions before allowing "Start Meeting"

### Runtime Permission Checks
Even after onboarding, the app verifies permissions each time you:
- Start a new meeting
- This prevents errors if permissions were revoked in System Settings

### Error Messages
The app provides clear error messages if permissions are missing:
- "⚠️ Speech recognition permission required..."
- "⚠️ Microphone permission required..."
- "⚠️ Screen Recording permission required..."

Each message directs you to the specific System Settings panel.

## What Was Fixed

### Previous Issues
1. ❌ No onboarding screen
2. ❌ Permissions requested during meeting start (too late)
3. ❌ Empty permission check in AudioCaptureManager
4. ❌ No screen recording permission verification
5. ❌ Poor error messages
6. ❌ No Siri & Dictation check (causing silent failures)

### Current Implementation
1. ✅ Dedicated onboarding screen on first launch
2. ✅ All permissions requested upfront
3. ✅ Proper screen recording permission check
4. ✅ Clear status indicators for each permission
5. ✅ Helpful error messages with guidance
6. ✅ Runtime verification before starting meetings
7. ✅ Direct links to System Settings
8. ✅ Siri & Dictation status verification with guidance

## Next Steps

After granting all permissions:
1. Click "Get Started" to close onboarding
2. You'll see the main ConvoCraft interface
3. Click "Start Meeting" to begin recording and transcription
4. Speak or play audio to see real-time transcription

Enjoy using ConvoCraft! 🎉
