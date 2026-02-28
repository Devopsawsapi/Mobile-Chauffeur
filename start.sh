#!/bin/bash

# Build Flutter Web
flutter build web --release

# Serve le dossier build/web
cd build/web
python3 -m http.server 8080