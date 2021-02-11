defmodule Chromoid.Devices.NFC do
  alias Chromoid.Repo
  import Ecto.Query

  alias Chromoid.Devices.NFC.{ISO14443a, WebHook, Action}

  def get_iso14443a_by_uid(device_id, uid) do
    Repo.one(from nfc in ISO14443a, where: nfc.device_id == ^device_id and nfc.abtUid == ^uid)
  end

  def get_iso14443a(id) do
    Repo.one!(from nfc in ISO14443a, where: nfc.id == ^id)
  end

  def delete_webhook(%ISO14443a{id: nfc_id}, id) do
    Repo.one!(
      from webhook in WebHook, where: webhook.nfc_iso14443a_id == ^nfc_id and webhook.id == ^id
    )
    |> Repo.delete()
  end

  def load_webhooks(%ISO14443a{id: nfc_id}) do
    # Repo.preload(nfc, [:webhooks])
    Repo.all(from webhook in WebHook, where: webhook.nfc_iso14443a_id == ^nfc_id)
  end

  def new_webhook(%ISO14443a{id: id}, attrs) do
    WebHook.changeset(%WebHook{nfc_iso14443a_id: id}, attrs)
    |> Repo.insert()
  end

  def change_webhook(%ISO14443a{id: id}, attrs) do
    WebHook.changeset(%WebHook{nfc_iso14443a_id: id}, attrs)
  end

  def load_actions(%ISO14443a{id: nfc_id}) do
    Repo.all(
      from action in Action, where: action.nfc_iso14443a_id == ^nfc_id, preload: [:nfc_iso14443a]
    )
  end

  def new_action(%ISO14443a{id: id}, attrs) do
    Action.changeset(%Action{nfc_iso14443a_id: id}, attrs)
    |> Repo.insert()
  end

  def delete_action(%ISO14443a{id: nfc_id}, id) do
    Repo.one!(
      from action in Action, where: action.nfc_iso14443a_id == ^nfc_id and action.id == ^id
    )
    |> Repo.delete()
  end

  def change_action(%ISO14443a{id: id}, attrs) do
    Action.changeset(%Action{nfc_iso14443a_id: id}, attrs)
  end
end
