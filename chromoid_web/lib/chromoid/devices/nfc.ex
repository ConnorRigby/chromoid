defmodule Chromoid.Devices.NFC do
  alias Chromoid.Repo
  import Ecto.Query

  alias Chromoid.Devices.NFC.{ISO14443a, WebHook}

  def get_iso14443a_by_uid(device_id, uid) do
    Repo.one(from nfc in ISO14443a, where: nfc.device_id == ^device_id and nfc.abtUid == ^uid)
  end

  def load_webhooks(%ISO14443a{id: nfc_id}) do
    # Repo.preload(nfc, [:webhooks])
    Repo.all(from webhook in WebHook, where: webhook.nfc_iso14443a_id == ^nfc_id)
  end

  def new_webhook(%ISO14443a{id: id}, attrs) do
    WebHook.changeset(%WebHook{nfc_iso14443a_id: id}, attrs)
    |> Repo.insert()
  end
end
