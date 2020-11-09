defmodule ChromoidLinkOctoPrint.PluginHTTP do


  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:chromoid_link_octo_print, :base_url)
  plug Tesla.Middleware.Headers, [
    {"X-Api-Key", Application.get_env(:chromoid_link_octo_print, :api_key)}
  ]
  plug Tesla.Middleware.JSON
end
