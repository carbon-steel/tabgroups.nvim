# Testing

When writing tests, avoid exporting internal functions. Instead, use `vim` api to create situations that exercise the logic you're testing. Also prefer to use the public commands of this plugin to set up testing scenarios rather than setting state like variables and fields directly.
