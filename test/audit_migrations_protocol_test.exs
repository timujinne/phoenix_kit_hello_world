defmodule PhoenixKitHelloWorld.AuditMigrationsProtocolTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixKitHelloWorld.AuditMigrations

  describe "protocol_missing/1" do
    test "missing only migrated_version/1 blames up/1's own re-read" do
      assert {:fail, "protocol", detail} =
               AuditMigrations.protocol_missing([{:migrated_version, 1}])

      assert detail =~ "up/1 cannot re-read the version it is about to change"
      refute detail =~ "mix phoenix_kit.update cannot drive"
    end

    test "missing migrated_version_runtime/1 blames mix phoenix_kit.update" do
      assert {:fail, "protocol", detail} =
               AuditMigrations.protocol_missing([{:migrated_version_runtime, 1}])

      assert detail =~ "mix phoenix_kit.update cannot drive this coordinator"
    end

    test "missing migrated_version_runtime/1 alongside migrated_version/1 still blames mix phoenix_kit.update" do
      assert {:fail, "protocol", detail} =
               AuditMigrations.protocol_missing([
                 {:migrated_version, 1},
                 {:migrated_version_runtime, 1}
               ])

      assert detail =~ "mix phoenix_kit.update cannot drive this coordinator"
    end
  end
end
