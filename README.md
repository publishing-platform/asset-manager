# Asset Manager
Manages uploaded assets (images, PDFs etc.) for applications on Publishing Platform

The app receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error. Deleted files return a 410 Gone response.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [publishing_platform_sidekiq][sidekiq].

## Licence

[MIT License](LICENSE)

[clamav]:https://www.clamav.net/
[sidekiq]:https://github.com/publishing-platform/publishing_platform_sidekiq
