defmodule Jalka2026Web.Layouts do
  @moduledoc """
  This module defines layout components for the application.
  """
  use Jalka2026Web, :html

  embed_templates("layouts/*")

  @doc """
  Renders flash notices.
  """
  attr(:flash, :map, required: true)

  def flash_group(assigns) do
    ~H"""
    <p :if={Phoenix.Flash.get(@flash, :info)} class="alert alert-info" role="alert">
      <%= Phoenix.Flash.get(@flash, :info) %>
    </p>
    <p :if={Phoenix.Flash.get(@flash, :error)} class="alert alert-danger" role="alert">
      <%= Phoenix.Flash.get(@flash, :error) %>
    </p>
    """
  end
end
