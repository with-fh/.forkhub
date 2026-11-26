# Use the upstream release label for the signed Linux AppImage

ForkHub's public Linux AppImage should display the same product name and
client branding as signed upstream macOS and Windows builds. The native
installer and launcher already use DeepSeek Harness. The local client
profile leaks a DSH Local Build badge into the installed app.

- Apply after the ForkHub update channel and Linux support patches.
- When the catalog sets FORKHUB_LINUX_RELEASE=1 for a Linux release,
  build the client with the upstream official profile. Reuse that same
  profile when checking the build record before staging packages.
- Keep the native package identity and ForkHub update channel. Ordinary
  local builds and other platforms keep their existing build modes.
- The Linux catalog signs the finished AppImage with its own release key.
  The label and the publisher signature are controlled independently.
