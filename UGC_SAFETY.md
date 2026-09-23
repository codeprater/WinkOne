# WINK user-generated content safety

WINK is a local-first iOS app. Cards are exchanged over encrypted Multipeer
Connectivity or through the system share sheet; there is currently no WINK
server, account service, public feed, or remote moderation API.

## Implemented in the client

- The app is gated to users who affirm they are 18 or older and accept the
  zero-tolerance content policy.
- Text, display names, links, and place names are screened before sending and
  again before an incoming card is displayed. Filtered content is discarded.
- Users can report, block, or remove a card from the incoming card and Safety
  Center. Reporting immediately hides local content and blocks that sender.
- Received content has a stable content UUID. Each installation also has a
  private moderation identifier. The identifier is transmitted only as a
  moderation correlation value; it is not shown as a public identity.
- Reports retain masked evidence, the sender/content identifiers, timestamps,
  a 24-hour review deadline, and local removal/ejection audit timestamps.
- Safety Center provides developer contact information and prepares a report
  email containing the moderation identifiers needed for support triage.

## Required production backend contract

This contract is intentionally documented, not implemented with invented
credentials or an unavailable service. Before claiming server-side enforcement
in App Store review materials, implement a service that:

1. Accepts an authenticated report submission containing `reportID`,
   `senderModerationID`, `contentID`, reason, masked evidence, and timestamps.
2. Stores reports and evidence with access restricted to authorized moderators.
3. Supports moderator actions for remove-content, suspend/eject-sender,
   resolve-without-action, and appeal. Every action must be immutable-audited.
4. Returns sender/content enforcement decisions to the client and rejects
   suspended sender IDs during discovery, invitation, and message receipt.
5. Enforces the 24-hour response SLA and provides a monitored support mailbox.

The current local review queue is a transparent offline fallback. Its
remove/eject actions affect this device and its local history only; they cannot
delete an already-exported share-sheet copy or remotely eject another device.
Do not describe that local queue as server-side moderation.

## App Store Connect/manual configuration

- Keep the App Store Connect age rating at **18+** (`Info.plist` includes the
  matching internal metadata).
- Configure and monitor the support address in `WinkAgreement.supportEmail`.
- Before submission, provide App Review with a test path for the Safety Center,
  report flow, blocking, immediate removal, and developer contact.
- Signing, App Store Connect credentials, and backend deployment are outside
  this repository and must be configured by the developer; no credentials are
  stored here.
