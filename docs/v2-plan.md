# ConvoCraft v2 Plan

## Goal and scope

Build ConvoCraft v2 as a macOS-only meeting assistant, using native Apple frameworks and keeping audio, transcripts, and inference on-device. The plan covers durable recording, English transcription, generated notes, meeting search, and meeting Q&A.

## Phase 1: Durable meeting and audio foundation

- [ ] Define meeting lifecycle and persistent data models for meetings, audio tracks, transcript segments, notes, attendees/speakers, and folders.
- [ ] Replace summary-only JSON persistence with a versioned database and migration strategy.
- [ ] Add backup, trash/deletion, and recovery behavior for interrupted writes.
- [ ] Timestamp audio segments against a shared meeting clock; preserve track identity, start/end times, and gaps.
- [ ] Add pause/resume and accurate captured-duration accounting.
- [ ] Write recoverable audio parts so an interrupted recording can be resumed without overwriting prior data; join parts after recovery.
- [ ] Handle microphone/output device and sample-rate changes without silently losing or misaligning audio.
- [ ] Add microphone selection and device status reporting.
- [ ] Evaluate compressed, fragmented audio storage as an alternative to sequential WAV files while retaining separate tracks and crash recovery.

**Exit criteria:** A long recording with pauses, a device switch, and a forced app interruption produces playable, correctly aligned tracks and a recoverable meeting record.

## Phase 2: English transcription and speaker attribution

- [ ] Keep English (`en-US`) as the only supported spoken-language setting in v2.
- [ ] Use Apple SpeechAnalyzer for transcription on supported macOS versions; do not add Whisper or downloaded speech models.
- [ ] Resolve the macOS deployment target: SpeechAnalyzer requires macOS 26, so either raise the v2 minimum or retain the existing on-device Apple Speech implementation as a fallback on earlier versions.
- [ ] Preserve partial and final results, word/segment timing, and track identity; keep transcript timing aligned to the meeting clock.
- [ ] Surface transcription status and failures, including recognizer unavailability, backlog, failed segments, and restarts.
- [ ] Add Mac call-speaker naming through Accessibility APIs for supported call apps, with manual correction and clear permission handling.
- [ ] Detect likely microphone echo of system audio; allow users to inspect and restore filtered transcript lines.

**Exit criteria:** English speech transcribes in real time without unbounded backlog; saved segments retain track and meeting-time alignment; speaker labels are editable.

## Phase 3: Locally generated notes

- [ ] Add user-authored notes before and during meetings.
- [ ] Generate structured notes locally from the transcript and user notes using Apple Foundation Models where available.
- [ ] Retain the current extractive summary as a fallback on systems without Foundation Models.
- [ ] Handle long meetings by splitting transcripts into bounded parts, summarizing each part, then synthesizing final notes.
- [ ] Extract action items, decisions, open questions, risks, and next steps with speaker attribution where available.
- [ ] Support editing and regeneration without overwriting user edits.
- [ ] Add automatic title generation and clear model availability/error states.

**Exit criteria:** Long meeting notes cover the whole meeting, distinguish decisions from proposed actions, and do not overwrite user edits.

## Phase 4: Meeting Q&A and library search

- [ ] Add questions and answers grounded in one meeting's transcript and notes, with links to source passages.
- [ ] Persist conversation history and support cancelling answers.
- [ ] Add full-text search across meeting titles, notes, and transcripts, with highlighted snippets.
- [ ] Add folders and meeting organization.
- [ ] Add questions across meetings using full-text retrieval, with relevant source passages and citations to the meetings they came from.
- [ ] Add indexing and re-indexing for new, changed, imported, and deleted meetings.

**Exit criteria:** Full-text search works without optional models; answers return relevant, traceable sources from one or multiple meetings.

## Phase 5: Export

- [ ] Copy or export notes and transcripts as Markdown.

**Exit criteria:** Exported notes and transcripts are readable and usable outside the app.

## Recommended implementation order

1. Durable meeting and audio foundation
2. English transcription and speaker attribution
3. Locally generated notes
4. Full-text search, folders, and meeting Q&A
5. Markdown export

This order makes recordings and transcripts dependable before adding features that depend on them.
