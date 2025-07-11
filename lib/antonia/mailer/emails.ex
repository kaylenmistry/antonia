defmodule Antonia.Mailer.Emails do
  @moduledoc """
  Templates for emails sent to users.
  """

  import Phoenix.Template, only: [embed_templates: 2]

  embed_templates "emails/*.mjml", suffix: "_mjml"
  embed_templates "emails/*.txt", suffix: "_txt"
end
