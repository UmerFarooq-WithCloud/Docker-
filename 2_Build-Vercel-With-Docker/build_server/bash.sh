#!/bin/bash
export Git_repo_url="$Git_repo_url"
git clone "$Git_repo_url" /app/output
exec node script.js

