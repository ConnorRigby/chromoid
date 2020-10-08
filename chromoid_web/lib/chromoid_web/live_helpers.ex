defmodule ChromoidWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `ChromoidWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal @socket, ChromoidWeb.EntryLive.FormComponent,
        id: @entry.id || :new,
        action: @live_action,
        entry: @entry,
        return_to: Routes.entry_index_path(@socket, :index) %>
  """
  def live_modal(socket, component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(socket, ChromoidWeb.ModalComponent, modal_opts)
  end
end
