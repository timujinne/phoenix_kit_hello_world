defmodule PhoenixKitHelloWorld.AuditMigrationsMarkerTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixKitHelloWorld.AuditMigrations
  alias PhoenixKit.Migrations.Postgres.Helpers

  describe "absent_schema/0" do
    test "is a prefix core's own validator accepts" do
      assert Helpers.validate_prefix!(AuditMigrations.absent_schema()) == :ok
    end
  end

  describe "parse_marker/1" do
    test "a bare version number parses with no namespace" do
      assert AuditMigrations.parse_marker("1") == {:ok, 1, nil}
    end

    test "surrounding whitespace is trimmed" do
      assert AuditMigrations.parse_marker("  12 ") == {:ok, 12, nil}
    end

    test "a namespaced marker parses with its namespace" do
      assert AuditMigrations.parse_marker("pkl_schema:1") == {:ok, 1, "pkl_schema"}
      assert AuditMigrations.parse_marker("pkb_schema:4") == {:ok, 4, "pkb_schema"}
    end

    test "prose is not a marker" do
      assert AuditMigrations.parse_marker("Dashboard layouts per user") == :error
    end

    test "a namespace with no version is not a marker" do
      assert AuditMigrations.parse_marker("schema:") == :error
    end

    test "trailing garbage after the version is not a marker" do
      assert AuditMigrations.parse_marker("pkl_schema:1x") == :error
    end
  end

  describe "classify_comment/2" do
    test "a bare number is :ok under the renamed check label" do
      assert {:ok, "version marker is a version", "my_table is marked V01"} =
               AuditMigrations.classify_comment("my_table", "1")
    end

    test "a namespaced marker is :ok and names the namespace in the detail" do
      assert {:ok, "version marker is a version",
              "my_table is marked V01 (marker `pkl_schema:1`)"} =
               AuditMigrations.classify_comment("my_table", "pkl_schema:1")
    end

    test "prose is :fail under the renamed check label" do
      assert {:fail, "version marker is a version", detail} =
               AuditMigrations.classify_comment("my_table", "Dashboard layouts per user")

      assert detail =~ "carries prose, not a version"
    end
  end
end
