package __PACKAGE__

import androidx.core.content.FileProvider

// Own subclass so it never clashes with FileProviders declared by plugins.
class UpdateFileProvider : FileProvider()
