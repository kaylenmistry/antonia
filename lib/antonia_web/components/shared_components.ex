defmodule AntoniaWeb.SharedComponents do
  @moduledoc """
  Shared components used across multiple LiveViews to reduce complexity and duplication.
  """
  use Phoenix.Component
  use Gettext, backend: AntoniaWeb.Gettext

  # Import verified routes for navigation
  use Phoenix.VerifiedRoutes,
    endpoint: AntoniaWeb.Endpoint,
    router: AntoniaWeb.Router,
    statics: AntoniaWeb.static_paths()

  import AntoniaWeb.CoreComponents
  import SaladUI.Card
  import SaladUI.Badge
  import SaladUI.Dialog

  @doc """
  A reusable card component for displaying entity information.
  """
  attr :entity, :map, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :actions, :list, default: []
  attr :stats, :list, default: []
  attr :class, :string, default: ""
  attr :phx_click, :string, default: nil
  attr :phx_value_id, :string, default: nil

  def entity_card(assigns) do
    ~H"""
    <.card
      class={"p-6 hover:shadow-lg transition-shadow #{@class}"}
      phx-click={@phx_click}
      phx-value-id={@phx_value_id}
    >
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="text-lg font-semibold text-gray-900">{@title}</h3>
          <%= if @subtitle do %>
            <p class="text-sm text-gray-500 mt-1">{@subtitle}</p>
          <% end %>
        </div>
        <%= if @stats != [] do %>
          <.badge variant="secondary">
            {render_stats(@stats)}
          </.badge>
        <% end %>
      </div>

      <%= if @stats != [] do %>
        <div class="space-y-2 mb-4">
          <%= for stat <- @stats do %>
            <div class="flex items-center text-sm text-gray-600">
              <.icon name={stat.icon} class="w-4 h-4 mr-2 text-gray-400" />
              <span>{stat.label}: {stat.value}</span>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @actions != [] do %>
        <div class="flex gap-2">
          <%= for action <- @actions do %>
            <.link navigate={action.navigate} class={action.class || "flex-1"}>
              <SaladUI.Button.button
                variant={action.variant || "outline"}
                class={action.button_class || "w-full"}
              >
                <.icon name={action.icon} class="w-4 h-4 mr-2" />
                {action.label}
              </SaladUI.Button.button>
            </.link>
          <% end %>
        </div>
      <% end %>
    </.card>
    """
  end

  @doc """
  A reusable empty state component.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :class, :string, default: ""

  def empty_state(assigns) do
    ~H"""
    <.card class={"text-center py-12 #{@class}"}>
      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <.icon name={@icon} class="w-8 h-8 text-gray-400" />
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">{@title}</h3>
      <p class="text-gray-600 mb-4">{@description}</p>
    </.card>
    """
  end

  @doc """
  A reusable form dialog component using SaladUI.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :form, :any, required: true
  attr :submit_event, :string, required: true
  attr :validate_event, :string, default: nil
  attr :fields, :list, required: true
  attr :submit_label, :string, default: "Save"
  attr :cancel_label, :string, default: "Cancel"
  attr :class, :string, default: "sm:max-w-[500px]"

  def form_dialog(assigns) do
    ~H"""
    <.dialog id={@id} on-close="dialog_closed">
      <.dialog_trigger>
        <SaladUI.Button.button variant="outline">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" />
          {@title}
        </SaladUI.Button.button>
      </.dialog_trigger>
      <.dialog_content class={@class}>
        <.dialog_header>
          <.dialog_title>{@title}</.dialog_title>
          <.dialog_description>{@description}</.dialog_description>
        </.dialog_header>

        <.form for={@form} phx-submit={@submit_event} phx-change={@validate_event} class="space-y-4">
          <%= for field <- @fields do %>
            <div>
              <.input
                field={@form[field.name]}
                type={Map.get(field, :type, "text")}
                label={field.label}
                placeholder={field.placeholder}
                class={Map.get(field, :class, "mt-1")}
                required={Map.get(field, :required, false)}
                min={Map.get(field, :min)}
                max={Map.get(field, :max)}
                step={Map.get(field, :step)}
              />
            </div>
          <% end %>

          <.dialog_footer>
            <SaladUI.Button.button type="submit">
              <.icon name="hero-check" class="w-4 h-4 mr-2" />
              {@submit_label}
            </SaladUI.Button.button>
            <SaladUI.Button.button type="button" data-action="close" variant="outline">
              {@cancel_label}
            </SaladUI.Button.button>
          </.dialog_footer>
        </.form>
      </.dialog_content>
    </.dialog>
    """
  end

  @doc """
  A reusable revenue table component.
  """
  attr :revenue_data, :map, required: true
  attr :group, :map, required: true
  attr :building, :map, required: true
  attr :class, :string, default: ""

  def revenue_table(assigns) do
    ~H"""
    <div class={["bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden", @class]}>
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-xl font-semibold text-gray-900">{gettext("Store Revenue Details")}</h2>
            <p class="text-sm text-gray-600 mt-1">
              {gettext("Monthly revenue breakdown by store (%{years})",
                years: "#{Enum.min(@revenue_data.years)}-#{Enum.max(@revenue_data.years)}"
              )}
            </p>
          </div>
          <button
            phx-click="export_excel"
            class="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors shadow-sm hover:shadow-md"
          >
            <.icon name="hero-arrow-down-tray" class="h-4 w-4" />
            <span>{gettext("Export to Excel")}</span>
          </button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="sticky left-0 z-10 bg-gray-50 px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-r border-gray-200 min-w-[120px]">
                {gettext("Unit")}
              </th>
              <th class="px-2 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider border-r border-gray-200 min-w-[80px]">
                m²
              </th>
              <th class="px-2 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider border-r border-gray-200 min-w-[60px]">
                {gettext("Year")}
              </th>
              <%= for month_name <- @revenue_data.month_names do %>
                <th class="px-2 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[90px]">
                  {month_name}
                </th>
              <% end %>
              <th class="px-2 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider border-l border-gray-300 min-w-[100px]">
                {gettext("Total")}
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for {store, store_index} <- Enum.with_index(@revenue_data.stores) do %>
              <%= for {year, year_index} <- Enum.with_index(@revenue_data.years) do %>
                <tr class="hover:bg-gray-50">
                  <!-- Store Name and Area - only show on first row -->
                  <%= if year_index == 0 do %>
                    <td
                      rowspan={length(@revenue_data.years)}
                      class="sticky left-0 z-10 bg-white px-4 py-2 border-r border-gray-200 align-middle"
                    >
                      <div class="font-semibold text-gray-900">{store.name}</div>
                    </td>
                    <td
                      rowspan={length(@revenue_data.years)}
                      class="px-2 py-2 text-center border-r border-gray-200 align-middle"
                    >
                      <div class="text-sm text-gray-500">{store.area || "-"}</div>
                    </td>
                  <% end %>
                  
    <!-- Year -->
                  <td class="px-2 py-2 text-center border-r border-gray-200">
                    <div class="text-sm font-medium text-gray-900">{year}</div>
                  </td>
                  
    <!-- Monthly Revenue -->
                  <%= for month <- @revenue_data.months do %>
                    <% month_data =
                      get_in(store.revenue_by_period, [year, month]) ||
                        %{revenue: 0, percentage_change: nil} %>
                    <td class="px-2 py-2 text-center">
                      <.link
                        navigate={
                          ~p"/app/groups/#{@group.id}/buildings/#{@building.id}/stores/#{store.id}?year=#{year}&month=#{month}"
                        }
                        class="block space-y-1 cursor-pointer hover:bg-blue-50 rounded p-1 transition-colors"
                      >
                        <div class="text-sm font-medium text-gray-900">
                          {format_currency(month_data.revenue)}
                        </div>
                        <%= if year == Enum.max(@revenue_data.years) and month_data.percentage_change do %>
                          <div class="flex justify-center">
                            <span class={"text-xs font-medium px-1.5 py-0.5 rounded #{percentage_change_class(month_data.percentage_change)}"}>
                              {format_percentage_change(month_data.percentage_change)}
                            </span>
                          </div>
                        <% end %>
                      </.link>
                    </td>
                  <% end %>
                  
    <!-- Year Total -->
                  <% year_total =
                    Enum.reduce(@revenue_data.months, 0, fn month, acc ->
                      revenue = get_in(store.revenue_by_period, [year, month, :revenue]) || 0
                      acc + revenue
                    end) %>
                  <td class="px-2 py-2 text-center bg-gray-50 border-l border-gray-300">
                    <div class="space-y-1">
                      <div class="text-sm font-semibold text-gray-900">
                        {format_currency(year_total)}
                      </div>
                      <%= if year == Enum.max(@revenue_data.years) do %>
                        <% prev_year_total =
                          Enum.reduce(@revenue_data.months, 0, fn month, acc ->
                            revenue =
                              get_in(store.revenue_by_period, [year - 1, month, :revenue]) || 0

                            acc + revenue
                          end) %>
                        <% total_change = calculate_percentage_change(year_total, prev_year_total) %>
                        <%= if total_change do %>
                          <div class="flex justify-center">
                            <span class={"text-xs font-medium px-1.5 py-0.5 rounded #{percentage_change_class(total_change)}"}>
                              {format_percentage_change(total_change)}
                            </span>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
              
    <!-- Add spacing between stores -->
              <%= if store_index < length(@revenue_data.stores) - 1 do %>
                <tr>
                  <td colspan="16" class="h-2 bg-gray-50"></td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @doc """
  A reusable stats summary component.
  """
  attr :stats, :list, required: true
  attr :class, :string, default: ""

  def stats_summary(assigns) do
    ~H"""
    <div class={["grid grid-cols-1 md:grid-cols-3 gap-6", @class]}>
      <%= for stat <- @stats do %>
        <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900 mb-2">{stat.title}</h3>
          <p class="text-2xl font-bold text-gray-900 mb-2">{format_currency(stat.value)}</p>
          <%= if stat.change do %>
            <div class="flex items-center space-x-2">
              <span class={"text-xs font-medium px-1.5 py-0.5 rounded #{percentage_change_class(stat.change)}"}>
                {format_percentage_change(stat.change)}
              </span>
              <span class="text-xs text-gray-500">{stat.change_label}</span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp render_stats(stats) do
    case stats do
      [%{count: count, label: label}] -> "#{count} #{label}"
      _ -> "#{length(stats)} items"
    end
  end

  defp format_currency(amount) when is_number(amount) do
    formatted_amount = :erlang.float_to_binary(amount, decimals: 0)
    "€#{String.replace(formatted_amount, ~r/\B(?=(\d{3})+(?!\d))/, ",")}"
  end

  defp format_currency(_), do: "€0"

  defp format_percentage_change(nil), do: ""
  defp format_percentage_change(change) when change > 0, do: "+#{change}%"
  defp format_percentage_change(change), do: "#{change}%"

  defp percentage_change_class(nil), do: ""
  defp percentage_change_class(change) when change > 0, do: "text-green-600 bg-green-50"
  defp percentage_change_class(change) when change < 0, do: "text-red-600 bg-red-50"
  defp percentage_change_class(_), do: "text-gray-400"

  defp calculate_percentage_change(current, previous) when previous > 0 do
    result = (current - previous) / previous * 100
    Float.round(result, 1)
  end

  defp calculate_percentage_change(current, 0) when current > 0, do: 100.0
  defp calculate_percentage_change(_, _), do: nil
end
