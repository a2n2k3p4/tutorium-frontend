# Learn Page Jitsi Integration

The backend now returns the full Jitsi Meet URL for each class session. Always pass this value into `LearnPage.jitsiMeetingUrl` so the page can extract the correct server, room, and optional JWT token automatically.

## Opening the page

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => LearnPage(
      classSessionId: session.id,
      className: session.className,
      teacherName: session.teacherName,
      jitsiMeetingUrl: session.jitsiMeetingUrl,
      isTeacher: currentUser.isTeacher,
    ),
  ),
);
```

- `jitsiMeetingUrl` must include the scheme, host, and meeting slug that the backend generated, for example `https://vc.tutorium.io/rooms/session-42?jwt=abc...`.
- Query parameters such as `jwt` or `token` are forwarded to Jitsi automatically, so there is no extra parsing required on the caller side.
- If no link is provided the page will show an error; keep the fallback `.env` value (`JITSI_URL`) only for local testing without backend data.

## Reusing the helper

`createConferenceOptions` in `lib/pages/learn/function.dart` now accepts an optional `jitsiMeetingUrl` argument. Supply the same backend URL when building custom flows outside of `LearnPage` so the Jitsi SDK joins the correct room with the right authorization token.
