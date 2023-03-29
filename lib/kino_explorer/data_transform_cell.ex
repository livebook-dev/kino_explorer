defmodule KinoExplorer.DataTransformCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets/data_transform_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Data transform"

  alias Explorer.DataFrame

  @grouped_fields_operations ["filters", "fill_missing"]
  @validation_by_type [:filters, :fill_missing]
  @as_atom ["direction", "type", "operation_type", "strategy", "query"]
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
    operations = attrs["operations"]
    operations = if operations, do: normalize_operations(operations), else: default_operations()

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
      "fields" => updated_fields
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

  def handle_event("update_field", %{"operation_type" => operation_type} = fields, ctx)
      when operation_type in @grouped_fields_operations do
    {field, value, idx, operation_type} =
      {fields["field"], fields["value"], fields["idx"], String.to_atom(operation_type)}

    updated_operation = updates_for_grouped_fields(operation_type, field, value, idx, ctx)
    updated_operations = List.replace_at(ctx.assigns.operations, idx, updated_operation)
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "update_operation", %{"idx" => idx, "fields" => updated_operation})
    {:noreply, ctx}
  end

  def handle_event("update_field", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)
    updated_operations = put_in(ctx.assigns.operations, [Access.at(idx), field], parsed_value)
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{"idx" => idx, "fields" => %{field => parsed_value}})

    {:noreply, ctx}
  end

  def handle_event("add_inner_value", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)
    updated_value = get_in(ctx.assigns.operations, [Access.at(idx), field]) ++ [parsed_value]

    updated_operations = put_in(ctx.assigns.operations, [Access.at(idx), field], updated_value)
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{
      "idx" => idx,
      "fields" => %{field => updated_value}
    })

    {:noreply, ctx}
  end

  def handle_event("remove_inner_value", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)

    updated_value =
      get_in(ctx.assigns.operations, [Access.at(idx), field]) |> List.delete(parsed_value)

    updated_operations = put_in(ctx.assigns.operations, [Access.at(idx), field], updated_value)
    ctx = assign(ctx, operations: updated_operations)

    broadcast_event(ctx, "update_operation", %{
      "idx" => idx,
      "fields" => %{field => updated_value}
    })

    {:noreply, ctx}
  end

  def handle_event("add_operation", %{"operation_type" => operation_type, "idx" => idx}, ctx) do
    new_operation = operation_type |> String.to_existing_atom() |> default_operation()
    updated_operations = List.insert_at(ctx.assigns.operations, idx, new_operation)

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})

    {:noreply, ctx}
  end

  def handle_event("add_operation", %{"operation_type" => operation_type}, ctx) do
    operations = ctx.assigns.operations
    new_operation = operation_type |> String.to_existing_atom() |> default_operation()
    has_pivot_wider = Enum.any?(operations, &(&1["operation_type"] == "pivot_wider"))

    updated_operations =
      if has_pivot_wider and operation_type != "pivot_wider",
        do: List.insert_at(operations, -2, new_operation),
        else: operations ++ [new_operation]

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})

    {:noreply, ctx}
  end

  def handle_event("move_operation", %{"removedIndex" => remove, "addedIndex" => add}, ctx) do
    {operation, operations} = List.pop_at(ctx.assigns.operations, remove)
    updated_operations = List.insert_at(operations, add, operation)
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})

    {:noreply, ctx}
  end

  def handle_event("remove_operation", %{"idx" => idx}, ctx) do
    updated_operations = if idx, do: List.delete_at(ctx.assigns.operations, idx), else: []
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})

    {:noreply, ctx}
  end

  defp updates_for_data_frame(data_frame) do
    %{
      root_fields: %{"data_frame" => data_frame, "assign_to" => nil},
      operations: default_operations()
    }
  end

  defp updates_for_grouped_fields(:fill_missing, field, value, idx, ctx) do
    current_fill = get_in(ctx.assigns.operations, [Access.at(idx)])
    column = if field == "column", do: value, else: current_fill["column"]
    type = column_type(column, ctx)
    default_scalar = if type == "boolean", do: "true"
    message = if field == "scalar", do: validation_message(:fill_missing, type, value)

    if field == "column" do
      %{
        "column" => column,
        "strategy" => "forward",
        "scalar" => default_scalar,
        "type" => type,
        "active" => current_fill["active"],
        "operation_type" => "fill_missing",
        "message" => message
      }
    else
      Map.merge(current_fill, %{field => value, "message" => message})
    end
  end

  defp updates_for_grouped_fields(:filters, field, value, idx, ctx) do
    current_filter = get_in(ctx.assigns.operations, [Access.at(idx)])
    column = if field == "column", do: value, else: current_filter["column"]
    type = column_type(column, ctx)
    default_value = if type == "boolean", do: "true"
    message = if field == "value", do: validation_message(:filters, type, value)

    if field == "column" do
      %{
        "filter" => "equal",
        "column" => column,
        "value" => default_value,
        "type" => type,
        "message" => message,
        "active" => current_filter["active"],
        "operation_type" => "filters"
      }
    else
      Map.merge(current_filter, %{field => value, "message" => message})
    end
  end

  defp column_type(column, ctx) do
    df = ctx.assigns.root_fields["data_frame"]
    data = ctx.assigns.data_options

    Enum.find_value(data, &(&1.variable == df && Map.get(&1.columns, column)))
    |> Atom.to_string()
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
    |> Map.put("missing_require", ctx.assigns.missing_require)
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
    missing_require = attrs.missing_require

    nodes =
      attrs.operations
      |> Enum.map(&Map.new(&1, fn {k, v} -> convert_field(k, v) end))
      |> Enum.chunk_by(& &1.operation_type)
      |> Enum.map(&(to_quoted(&1) |> Map.merge(%{module: attrs.data_frame_alias})))

    root = build_root(df)

    nodes
    |> Enum.reduce(root, &apply_node/2)
    |> build_var(variable)
    |> build_missing_require(missing_require)
  end

  defp to_quoted([%{operation_type: :fill_missing} | _] = fill_missing) do
    fill_missing_args =
      for fill <- fill_missing, fill.active, fill.column do
        build_fill_missing(fill)
      end
      |> Enum.reject(&(&1 == nil))
      |> then(fn args -> if args != [], do: [args] end)

    %{field: :fill_missing, name: :mutate, args: fill_missing_args}
  end

  defp to_quoted([%{operation_type: :filters} | _] = filters) do
    filters_args =
      for filter <- filters, filter.active do
        build_filter([filter.column, filter.filter, filter.value, filter.type])
      end
      |> Enum.reject(&(&1 == nil))
      |> case do
        [] -> nil
        args -> Enum.reduce(args, &{:and, [], [&2, &1]}) |> then(&[&1])
      end

    %{field: :filter, name: :filter, args: filters_args}
  end

  defp to_quoted([%{operation_type: :sorting} | _] = sorting) do
    sorting_args =
      for sort <- sorting, sort.active, sort.direction != nil and sort.sort_by != nil do
        {sort.direction, quoted_column(sort.sort_by)}
      end
      |> then(fn args -> if args != [], do: [args] end)

    %{field: :sorting, name: :arrange, args: sorting_args}
  end

  defp to_quoted([%{operation_type: :summarise} | _] = summarization) do
    summarize_args =
      for summarize <- summarization, column <- summarize.columns,
          summarize.query,
          summarize.active do
        {String.to_atom("#{column}_#{summarize.query}"), quote do
          unquote(summarize.query)(unquote(quoted_column(column)))
        end}
      end
      |> then(fn args -> if args != [], do: [args] end)
    %{field: :summarise, name: :summarise, args: summarize_args}
  end

  defp to_quoted([
         %{operation_type: :pivot_wider, names_from: names, values_from: values, active: active}
       ]) do
    pivot_wider_args = if names && values && active, do: build_pivot_wider(names, values)
    %{field: :pivot_wider, name: :pivot_wider, args: pivot_wider_args}
  end

  defp to_quoted([%{operation_type: :group_by, group_by: group_by, active: active}]) do
    group_by_args = if group_by && active, do: build_group_by(group_by)
    %{field: :group_by, name: :group_by, args: group_by_args}
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

  defp build_missing_require(acc, nil), do: acc

  defp build_missing_require(acc, missing_require) do
    quote do
      require unquote(missing_require)
      unquote(acc)
    end
  end

  defp build_pivot_wider(_names, []), do: nil
  defp build_pivot_wider(names, [values]), do: [names, values]
  defp build_pivot_wider(names, values), do: [names, values]

  defp build_group_by([]), do: nil
  defp build_group_by([group_by]), do: [group_by]
  defp build_group_by(group_by), do: [group_by]

  defp build_filter([column, filter, value, type] = args) do
    with true <- Enum.all?(args, &(&1 != nil)),
         {:ok, filter_value} <- cast_typed_value(type, value) do
      {String.to_atom(filter), [], [quoted_column(column), filter_value]}
    else
      _ -> nil
    end
  end

  defp build_fill_missing(%{column: column, strategy: :scalar, scalar: scalar, type: type}) do
    with true <- scalar != nil,
         {:ok, scalar} <- cast_typed_value(type, scalar) do
      build_fill_missing(column, scalar)
    else
      _ -> nil
    end
  end

  defp build_fill_missing(%{column: column, strategy: strategy}) do
    build_fill_missing(column, strategy)
  end

  defp build_fill_missing(column, value) do
    {String.to_atom(column),
     quote do
       fill_missing(unquote(quoted_column(column)), unquote(value))
     end}
  end

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
    [default_operation(:filters)]
  end

  defp default_operation(:filters) do
    %{
      "filter" => nil,
      "column" => nil,
      "value" => nil,
      "type" => "string",
      "active" => true,
      "operation_type" => "filters"
    }
  end

  defp default_operation(:fill_missing) do
    %{
      "column" => nil,
      "strategy" => "forward",
      "scalar" => nil,
      "type" => "string",
      "active" => true,
      "operation_type" => "fill_missing"
    }
  end

  defp default_operation(:sorting) do
    %{"sort_by" => nil, "direction" => "asc", "active" => true, "operation_type" => "sorting"}
  end

  defp default_operation(:pivot_wider) do
    %{
      "names_from" => nil,
      "values_from" => [],
      "active" => true,
      "operation_type" => "pivot_wider"
    }
  end

  defp default_operation(:group_by) do
    %{"group_by" => [], "active" => true, "operation_type" => "group_by"}
  end

  defp default_operation(:summarise) do
    %{
      "columns" => [],
      "query" => nil,
      "active" => true,
      "operation_type" => "summarise"
    }
  end

  defp cast_typed_value(:boolean, "true"), do: {:ok, true}
  defp cast_typed_value(:boolean, "false"), do: {:ok, false}
  defp cast_typed_value(:boolean, _), do: nil

  defp cast_typed_value(:integer, value) do
    case Integer.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_typed_value(:float, value) do
    case Float.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_typed_value(type, value) when type in [:date, :datetime], do: to_date(type, value)
  defp cast_typed_value(_, value), do: {:ok, value}

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

  defp validation_message(operation, type, value) when operation in @validation_by_type do
    type = String.to_atom(type)

    case cast_typed_value(type, value) do
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
    if Explorer.DataFrame not in requires, do: Explorer.DataFrame
  end

  defp normalize_operations(operations) do
    has_pivot_wider = Enum.any?(operations, &(&1["operation_type"] == "pivot_wider"))

    if has_pivot_wider do
      List.update_at(operations, -1, fn operation ->
        Map.update!(operation, "values_from", fn values -> normalize_values_from(values) end)
      end)
    else
      operations
    end
  end

  defp normalize_values_from(values) when is_list(values), do: values
  defp normalize_values_from(nil), do: []
  defp normalize_values_from(values), do: [values]
end
