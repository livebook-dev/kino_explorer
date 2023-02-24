defmodule KinoExplorer.DataTransformCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets/data_transform_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Data transform"

  alias Explorer.DataFrame

  @as_atom ["direction", "type"]
  @filters %{
    "less" => "<",
    "less equal" => "<=",
    "equal" => "==",
    "not equal" => "!=",
    "greater equal" => ">=",
    "greater" => ">",
    "contains" => "contains"
  }

  @impl true
  def init(attrs, ctx) do
    root_fields = %{"data_frame" => attrs["data_frame"], "assign_to" => attrs["assign_to"]}
    operations = attrs["operations"] || default_operations()

    ctx =
      assign(ctx,
        root_fields: root_fields,
        operations: operations,
        data_frame_alias: Explorer.DataFrame,
        data_options: [],
        missing_require: nil
      )

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def scan_binding(pid, binding, env) do
    data_options =
      for {key, val} <- binding,
          is_struct(val, DataFrame),
          do: %{variable: Atom.to_string(key), columns: DataFrame.dtypes(val)}

    data_frame_alias = data_frame_alias(env)
    missing_require = missing_require(env)
    send(pid, {:scan_binding_result, data_options, data_frame_alias, missing_require})
  end

  @impl true
  def handle_connect(ctx) do
    payload = %{
      root_fields: ctx.assigns.root_fields,
      operations: ctx.assigns.operations,
      data_options: ctx.assigns.data_options,
      missing_require: ctx.assigns.missing_require
    }

    {:ok, payload, ctx}
  end

  @impl true
  def handle_info({:scan_binding_result, data_options, data_frame_alias, missing_require}, ctx) do
    ctx =
      assign(ctx,
        data_options: data_options,
        data_frame_alias: data_frame_alias,
        missing_require: missing_require
      )

    updated_fields =
      case {ctx.assigns.root_fields["data_frame"], data_options} do
        {nil, [%{variable: data_frame} | _]} -> updates_for_data_frame(data_frame)
        _ -> %{}
      end

    ctx = if updated_fields == %{}, do: ctx, else: assign(ctx, updated_fields)

    broadcast_event(ctx, "set_available_data", %{
      "data_options" => data_options,
      "fields" => updated_fields,
      "require" => missing_require
    })

    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => "data_frame", "value" => value}, ctx) do
    updated_fields = updates_for_data_frame(value)
    ctx = assign(ctx, updated_fields)
    broadcast_event(ctx, "update_data_frame", %{"fields" => updated_fields})
    {:noreply, ctx}
  end

  def handle_event("update_field", %{"operation_type" => nil} = fields, ctx) do
    {field, value} = {fields["field"], fields["value"]}
    parsed_value = parse_value(field, value)
    ctx = update(ctx, :root_fields, &Map.put(&1, field, parsed_value))
    broadcast_event(ctx, "update_root", %{"fields" => %{field => parsed_value}})
    {:noreply, ctx}
  end

  def handle_event("update_field", %{"operation_type" => "filters"} = fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    updated_filter = updates_for_filters(field, value, idx, ctx)
    updated_operation = List.replace_at(ctx.assigns.operations["filters"], idx, updated_filter)
    updated_operations = %{ctx.assigns.operations | "filters" => updated_operation}
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{
      "operation_type" => "filters",
      "idx" => idx,
      "fields" => updated_filter
    })

    {:noreply, ctx}
  end

  def handle_event("update_field", %{"operation_type" => operation_type} = fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)

    updated_operation =
      put_in(ctx.assigns.operations[operation_type], [Access.at(idx), field], parsed_value)

    updated_operations = %{ctx.assigns.operations | operation_type => updated_operation}
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{
      "operation_type" => operation_type,
      "idx" => idx,
      "fields" => %{field => parsed_value}
    })

    {:noreply, ctx}
  end

  def handle_event("add_operation", %{"operation_type" => operation_type}, ctx) do
    new_operation = operation_type |> String.to_existing_atom() |> default_operation()
    updated_operation = ctx.assigns.operations[operation_type] ++ [new_operation]
    updated_operations = %{ctx.assigns.operations | operation_type => updated_operation}
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{operation_type => updated_operation})

    {:noreply, ctx}
  end

  def handle_event("remove_operation", %{"operation_type" => operation_type, "idx" => idx}, ctx) do
    updated_operation =
      if idx, do: List.delete_at(ctx.assigns.operations[operation_type], idx), else: []

    updated_operations = %{ctx.assigns.operations | operation_type => updated_operation}
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{operation_type => updated_operation})

    {:noreply, ctx}
  end

  defp updates_for_data_frame(data_frame) do
    %{
      root_fields: %{"data_frame" => data_frame, "assign_to" => nil},
      operations: default_operations()
    }
  end

  defp updates_for_filters(field, value, idx, ctx) do
    current_filter = get_in(ctx.assigns.operations["filters"], [Access.at(idx)])
    df = ctx.assigns.root_fields["data_frame"]
    data = ctx.assigns.data_options
    column = if field == "column", do: value, else: current_filter["column"]
    filter = current_filter["filter"] || "equal"
    active = current_filter["active"]

    type =
      Enum.find_value(data, &(&1.variable == df && Map.get(&1.columns, column)))
      |> Atom.to_string()

    message = if field == "value", do: validation_message(:filter, type, value)

    case field do
      "column" ->
        %{
          "filter" => "equal",
          "column" => column,
          "value" => nil,
          "type" => type,
          "message" => message,
          "active" => active
        }

      "value" ->
        %{
          "filter" => filter,
          "column" => column,
          "value" => value,
          "type" => type,
          "message" => message,
          "active" => active
        }

      "filter" ->
        %{
          "filter" => value,
          "column" => column,
          "value" => nil,
          "type" => type,
          "message" => message,
          "active" => active
        }

      "active" ->
        %{
          "filter" => filter,
          "column" => column,
          "value" => current_filter["value"],
          "type" => type,
          "message" => message,
          "active" => value
        }
    end
  end

  defp parse_value(_field, ""), do: nil
  defp parse_value(_field, value), do: value

  defp convert_field(field, nil), do: {String.to_atom(field), nil}
  defp convert_field(field, ""), do: {String.to_atom(field), nil}

  defp convert_field("filter", value) do
    {String.to_atom("filter"), Map.fetch!(@filters, value)}
  end

  defp convert_field(field, value) when field in @as_atom do
    {String.to_atom(field), String.to_atom(value)}
  end

  defp convert_field(field, value), do: {String.to_atom(field), value}

  @impl true
  def to_attrs(ctx) do
    ctx.assigns.root_fields
    |> Map.put("operations", ctx.assigns.operations)
    |> Map.put("data_frame_alias", ctx.assigns.data_frame_alias)
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

  defp to_quoted(%{"data_frame" => df, "assign_to" => variable} = attrs) do
    attrs = Map.new(attrs, fn {k, v} -> convert_field(k, v) end)

    sorting_args =
      for sort <- attrs.operations["sorting"],
          sort = Map.new(sort, fn {k, v} -> convert_field(k, v) end),
          sort.active,
          sort.direction != nil and sort.sort_by != nil do
        {sort.direction, quoted_column(sort.sort_by)}
      end
      |> then(fn args -> if args != [], do: [args] end)

    sorting = [
      %{
        field: :sorting,
        name: :arrange,
        module: attrs.data_frame_alias,
        args: sorting_args
      }
    ]

    filters =
      for filter <- attrs.operations["filters"],
          filter = Map.new(filter, fn {k, v} -> convert_field(k, v) end),
          filter.active do
        %{
          field: :filter,
          name: :filter,
          module: attrs.data_frame_alias,
          args: build_filter([filter.column, filter.filter, filter.value, filter.type])
        }
      end

    pivot = [
      %{
        field: :pivot_wider,
        name: :pivot_wider,
        module: attrs.data_frame_alias,
        args: build_pivot(attrs.operations["pivot_wider"])
      }
    ]

    nodes = filters ++ sorting ++ pivot
    root = build_root(df)
    Enum.reduce(nodes, root, &apply_node/2) |> build_var(variable)
  end

  defp build_root(df) do
    quote do
      unquote(Macro.var(String.to_atom(df), nil))
    end
  end

  defp build_var(acc, nil), do: acc

  defp build_var(acc, var) do
    quote do
      unquote({String.to_atom(var), [], nil}) = unquote(acc)
    end
  end

  defp build_filter([column, filter, value, type] = args) do
    with true <- Enum.all?(args, &(&1 != nil)),
         {:ok, filter_value} <- cast_filter_value(type, value) do
      [{String.to_atom(filter), [], [quoted_column(column), filter_value]}]
    else
      _ -> nil
    end
  end

  defp build_pivot([%{"names_from" => names, "values_from" => values, "active" => true}]) do
    if names && values, do: [names, values]
  end

  defp build_pivot(_), do: nil

  defp apply_node(%{args: nil}, acc), do: acc

  defp apply_node(%{field: _field, name: function, module: data_frame, args: args}, acc) do
    quote do
      unquote(acc) |> unquote(data_frame).unquote(function)(unquote_splicing(args))
    end
  end

  defp quoted_column(string) do
    var = String.to_atom(string)

    if Macro.classify_atom(var) == :identifier do
      {String.to_atom(string), [], nil}
    else
      quote do
        col(unquote(string))
      end
    end
  end

  defp default_operations() do
    %{
      "filters" => [default_operation(:filters)],
      "sorting" => [default_operation(:sorting)],
      "pivot_wider" => [default_operation(:pivot_wider)]
    }
  end

  defp default_operation(:filters) do
    %{"filter" => nil, "column" => nil, "value" => nil, "type" => "string", "active" => true}
  end

  defp default_operation(:sorting) do
    %{"sort_by" => nil, "direction" => "asc", "active" => true}
  end

  defp default_operation(:pivot_wider) do
    %{"names_from" => nil, "values_from" => nil, "active" => true}
  end

  defp cast_filter_value(:boolean, value), do: {:ok, String.to_atom(value)}

  defp cast_filter_value(:integer, value) do
    case Integer.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_filter_value(:float, value) do
    case Float.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_filter_value(type, value) when type in [:date, :datetime], do: to_date(type, value)
  defp cast_filter_value(_, value), do: {:ok, value}

  defp to_date(:date, value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> nil
    end
  end

  defp to_date(:datetime, value) do
    case DateTime.from_iso8601(value) do
      {:ok, date, _} -> {:ok, date}
      _ -> nil
    end
  end

  defp validation_message(:filter, type, value) do
    type = String.to_atom(type)

    case cast_filter_value(type, value) do
      {:ok, _} -> nil
      _ -> "invalid value for type #{type}"
    end
  end

  defp data_frame_alias(%Macro.Env{aliases: aliases}) do
    case List.keyfind(aliases, Explorer.DataFrame, 1) do
      {data_frame_alias, _} -> data_frame_alias
      nil -> Explorer.DataFrame
    end
  end

  defp missing_require(%Macro.Env{requires: requires}) do
    if Explorer.DataFrame not in requires, do: "require Explorer.DataFrame"
  end
end
