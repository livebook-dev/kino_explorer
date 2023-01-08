defmodule KinoExplorer.DataFrameCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets/data_frame_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "DataFrame"

  alias Explorer.DataFrame

  @as_atom ["order"]

  @impl true
  def init(attrs, ctx) do
    root_fields = %{
      "data_frame" => attrs["data_frame"]
    }

    operations = attrs["operations"] || default_operations()

    ctx =
      assign(ctx,
        root_fields: root_fields,
        operations: operations,
        explorer_alias: Explorer,
        data_options: [],
        missing_dep: missing_dep()
      )

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def scan_binding(pid, binding, env) do
    data_options =
      for {key, val} <- binding,
          is_struct(val, DataFrame),
          columns = DataFrame.names(val),
          types = dtypes(val, columns),
          do: %{variable: Atom.to_string(key), columns: columns, types: types}

    explorer_alias = explorer_alias(env)
    send(pid, {:scan_binding_result, data_options, explorer_alias})
  end

  @impl true
  def handle_connect(ctx) do
    payload = %{
      root_fields: ctx.assigns.root_fields,
      operations: ctx.assigns.operations,
      data_options: ctx.assigns.data_options,
      missing_dep: ctx.assigns.missing_dep
    }

    {:ok, payload, ctx}
  end

  @impl true
  def handle_info({:scan_binding_result, data_options, explorer_alias}, ctx) do
    ctx = assign(ctx, data_options: data_options, explorer_alias: explorer_alias)

    updated_fields =
      case {ctx.assigns.root_fields["data_frame"], data_options} do
        {nil, [%{variable: data_frame} | _]} -> updates_for_data_frame(ctx, data_frame)
        _ -> %{}
      end

    ctx = if updated_fields == %{}, do: ctx, else: assign(ctx, updated_fields)

    broadcast_event(ctx, "set_available_data", %{
      "data_options" => data_options,
      "fields" => updated_fields
    })

    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => "data_frame", "value" => value}, ctx) do
    IO.inspect(value)
    updated_fields = updates_for_data_frame(ctx, value)
    ctx = assign(ctx, updated_fields)
    broadcast_event(ctx, "update_data_frame", %{"fields" => updated_fields})
    {:noreply, ctx}
  end

  def handle_event("update_field", %{"operation" => nil, "field" => field, "value" => value}, ctx) do
    parsed_value = parse_value(field, value)
    ctx = update(ctx, :root_fields, &Map.put(&1, field, parsed_value))
    broadcast_event(ctx, "update_root", %{"fields" => %{field => parsed_value}})
    {:noreply, ctx}
  end

  def handle_event("update_field", %{"operation" => operation} = fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)

    updated_operation =
      put_in(ctx.assigns.operations[operation], [Access.at(idx), field], parsed_value)

    updated_operations = %{ctx.assigns.operations | operation => updated_operation}
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{
      "operation" => operation,
      "idx" => idx,
      "fields" => %{field => parsed_value}
    })

    {:noreply, ctx}
  end

  def handle_event("add_operation", %{"operation" => operation}, ctx) do
    new_operation = String.to_atom(operation) |> default_operation()
    updated_operation = ctx.assigns.operations[operation] ++ [new_operation]
    updated_operations = %{ctx.assigns.operations | operation => updated_operation}
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{operation => updated_operation})

    {:noreply, ctx}
  end

  def handle_event("remove_operation", %{"operation" => operation, "idx" => idx}, ctx) do
    updated_operation = List.delete_at(ctx.assigns.operations[operation], idx)
    updated_operations = %{ctx.assigns.operations | operation => updated_operation}
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{operation => updated_operation})

    {:noreply, ctx}
  end

  defp updates_for_data_frame(_ctx, data_frame) do
    %{
      root_fields: %{"data_frame" => data_frame},
      operations: default_operations()
    }
  end

  defp parse_value(_field, ""), do: nil
  defp parse_value(_field, value), do: value

  defp convert_field(field, nil), do: {String.to_atom(field), nil}

  defp convert_field(field, value) when field in @as_atom do
    {String.to_atom(field), String.to_atom(value)}
  end

  defp convert_field(field, value), do: {String.to_atom(field), value}

  @impl true
  def to_attrs(ctx) do
    ctx.assigns.root_fields
    |> Map.put("operations", ctx.assigns.operations)
    |> Map.put("explorer_alias", ctx.assigns.explorer_alias)
  end

  @impl true
  def to_source(attrs) do
    attrs
    |> to_quoted()
    |> Kino.SmartCell.quoted_to_string()
  end

  defp to_quoted(%{"data_frame" => nil}) do
    quote do
    end
  end

  defp to_quoted(%{"data_frame" => df} = attrs) do
    attrs = Map.new(attrs, fn {k, v} -> convert_field(k, v) end)

    sorting_args =
      for sort <- attrs.operations["sorting"],
          sort = Map.new(sort, fn {k, v} -> convert_field(k, v) end),
          sort.order != nil && sort.order_by != nil do
        build_sorting(sort.order, sort.order_by)
      end

    sorting = [
      %{
        field: :sorting,
        name: :arrange_with,
        module: attrs.explorer_alias,
        args: sorting_args
      }
    ]

    filters =
      for filter <- attrs.operations["filters"],
          filter = Map.new(filter, fn {k, v} -> convert_field(k, v) end) do
        %{
          field: :filter,
          name: :filter_with,
          module: attrs.explorer_alias,
          args: build_filter([filter.column, filter.filter, filter.value])
        }
      end

    nodes = sorting ++ filters
    root = build_root(df)
    Enum.reduce(nodes, root, &apply_node/2)
  end

  defp build_root(df) do
    quote do
      unquote(Macro.var(String.to_atom(df), nil))
    end
  end

  defp build_sorting(order, order_by), do: {order, order_by}

  defp build_filter([column, filter, value] = args) do
    if Enum.all?(args, &(&1 != nil)), do: build_filter(column, filter, value)
  end

  defp build_filter(column, filter, value) do
    {column, String.to_atom(filter), String.to_integer(value)}
  end

  defp apply_node(%{args: nil}, acc), do: acc
  defp apply_node(%{args: []}, acc), do: acc

  defp apply_node(%{field: :sorting, name: function, args: args}, acc) do
    args =
      Enum.map(args, fn {order, column} ->
        quote do
          {unquote(order), &1[unquote(column)]}
        end
      end)

    quote do
      unquote(acc)
      |> Explorer.DataFrame.unquote(function)(&unquote(args))
    end
  end

  defp apply_node(%{field: :filter, name: function, args: {column, filter, value}}, acc) do
    quote do
      unquote(acc)
      |> Explorer.DataFrame.unquote(function)(
        &Explorer.Series.unquote(filter)(&1[unquote(column)], unquote(value))
      )
    end
  end

  defp default_operations() do
    %{
      "filters" => [default_operation(:filters)],
      "sorting" => [default_operation(:sorting)]
    }
  end

  defp default_operation(:filters) do
    %{"filter" => "equal", "column" => nil, "value" => nil}
  end

  defp default_operation(:sorting) do
    %{"order_by" => nil, "order" => "asc"}
  end

  defp dtypes(val, columns) do
    dtypes = DataFrame.dtypes(val)
    Enum.map(columns, &(Map.fetch!(dtypes, &1) |> Atom.to_string()))
  end

  defp explorer_alias(%Macro.Env{aliases: aliases}) do
    case List.keyfind(aliases, Explorer, 1) do
      {explorer_alias, _} -> explorer_alias
      nil -> Explorer
    end
  end

  defp missing_dep() do
    unless Code.ensure_loaded?(Explorer) do
      ~s/{:explorer, "~> 0.5.0"}/
    end
  end
end
