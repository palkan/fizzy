# typed: true
# frozen_string_literal: true

# Loaded lazily by the app, so `tapioca gems` doesn't see them otherwise
require "active_record/connection_adapters/sqlite3_adapter"
require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_storage/service/s3_service"
