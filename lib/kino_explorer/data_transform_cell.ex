defmodule KinoExplorer.DataTransformCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets/data_transform_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Data transform"

  alias Explorer.DataFrame
  alias Explorer.Series

  @column_types [
    "binary",
    "boolean",
    "category",
    "date",
    "datetime[ms]",
    "datetime[μs]",
    "datetime[ns]",
    "float",
    "integer",
    "string",
    "time"
  ]
  @filter_options %{
    "binary" => ["equal", "contains", "not equal"],
    "boolean" => ["equal", "not equal"],
    "category" => ["equal", "contains", "not equal"],
    "date" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "datetime[ms]" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "datetime[μs]" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "datetime[ns]" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "float" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "integer" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"],
    "string" => ["equal", "contains", "not equal"],
    "time" => ["less", "less equal", "equal", "not equal", "greater equal", "greater"]
  }
  @fill_missing_options %{
    "binary" => ["forward", "backward", "max", "min", "scalar"],
    "boolean" => ["forward", "backward", "max", "min", "scalar"],
    "category" => ["forward", "backward", "max", "min", "scalar"],
    "date" => ["forward", "backward", "max", "min", "mean", "scalar"],
    "datetime[ms]" => ["forward", "backward", "max", "min", "mean", "scalar"],
    "datetime[μs]" => ["forward", "backward", "max", "min", "mean", "scalar"],
    "datetime[ns]" => ["forward", "backward", "max", "min", "mean", "scalar"],
    "float" => ["forward", "backward", "max", "min", "mean", "scalar", "nan"],
    "integer" => ["forward", "backward", "max", "min", "mean", "scalar"],
    "string" => ["forward", "backward", "max", "min", "scalar"],
    "time" => ["forward", "backward", "max", "min", "mean", "scalar"]
  }
  @summarise_options %{
    count: @column_types,
    max: ["integer", "float", "date", "time", "datetime[ms]", "datetime[μs]", "datetime[ns]"],
    mean: ["integer", "float"],
    median: ["integer", "float"],
    min: ["integer", "float", "date", "time", "datetime[ms]", "datetime[μs]", "datetime[ns]"],
    n_distinct: @column_types,
    nil_count: @column_types,
    standard_deviation: ["integer", "float"],
    sum: ["integer", "float", "boolean"],
    variance: ["integer", "float"]
  }
  @pivot_wider_types %{
    names_from: @column_types,
    values_from: [
      "date",
      "datetime[ms]",
      "datetime[μs]",
      "datetime[ns]",
      "float",
      "integer",
      "time",
      "category"
    ]
  }
  @queried_filter_options [
    "mean",
    "median",
    "quantile(10)",
    "quantile(20)",
    "quantile(30)",
    "quantile(40)",
    "quantile(60)",
    "quantile(70)",
    "quantile(80)",
    "quantile(90)"
  ]
  @queried_filter_types ["integer", "float"]

  @grouped_fields_operations ["filters", "fill_missing", "summarise"]
  @validation_by_type [:filters, :fill_missing]
  @as_atom ["direction", "operation_type", "strategy", "query"]
  @filters %{
    "less" => "<",
    "less equal" => "<=",
    "equal" => "==",
    "not equal" => "!=",
    "greater equal" => ">=",
    "greater" => ">",
    "contains" => "contains"
  }

  @multiselect_operations [:discard, :group_by]

  defguard is_queried(type, value)
           when type in @queried_filter_types and value in @queried_filter_options

  @impl true
  def init(attrs, ctx) do
    root_fields = %{
      "data_frame" => attrs["data_frame"],
      "assign_to" => attrs["assign_to"],
      "collect" => if(Map.has_key?(attrs, "collect"), do: attrs["collect"], else: true)
    }

    operations = attrs["operations"]
    operations = if operations, do: normalize_operations(operations), else: default_operations()

    ctx =
      assign(ctx,
        root_fields: root_fields,
        operations: operations,
        data_frame_alias: Explorer.DataFrame,
        data_frame_variables: %{},
        data_frames: [],
        binding: [],
        operation_options: %{
          fill_missing: @fill_missing_options,
          filter: @filter_options,
          summarise: @summarise_options,
          queried_filter: @queried_filter_options
        },
        operation_types: %{
          pivot_wider: @pivot_wider_types,
          queried_filter: @queried_filter_types
        },
        missing_require: nil
      )

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def scan_binding(pid, binding, env) do
    data_frame_alias = data_frame_alias(env)
    missing_require = missing_require(env)
    send(pid, {:scan_binding_result, binding, data_frame_alias, missing_require})
  end

  @impl true
  def handle_connect(ctx) do
    payload = %{
      root_fields: ctx.assigns.root_fields,
      operations: ctx.assigns.operations,
      data_frame_variables: ctx.assigns.data_frame_variables,
      operation_options: ctx.assigns.operation_options,
      operation_types: ctx.assigns.operation_types,
      missing_require: ctx.assigns.missing_require,
      data_frame_alias: ctx.assigns.data_frame_alias
    }

    {:ok, payload, ctx}
  end

  @impl true
  def handle_info({:scan_binding_result, binding, data_frame_alias, missing_require}, ctx) do
    data_frames =
      for {key, val} <- binding,
          valid_data(val),
          do: %{
            variable: Atom.to_string(key),
            data: val,
            data_frame: is_struct(val, DataFrame)
          }

    data_frame_variables = Enum.map(data_frames, &{&1.variable, &1.data_frame}) |> Enum.into(%{})

    ctx =
      assign(ctx,
        binding: binding,
        data_frames: data_frames,
        data_frame_variables: data_frame_variables,
        data_frame_alias: data_frame_alias,
        missing_require: missing_require
      )

    updated_fields =
      case {ctx.assigns.root_fields["data_frame"], Map.keys(data_frame_variables)} do
        {nil, [data_frame | _]} ->
          updates_for_data_frame(data_frame, ctx)

        _ ->
          %{
            root_fields: ctx.assigns.root_fields,
            operations: update_data_options(ctx.assigns.operations, ctx)
          }
      end

    ctx = assign(ctx, updated_fields)

    broadcast_event(ctx, "set_available_data", %{
      "data_frame_variables" => data_frame_variables,
      "data_frame_alias" => data_frame_alias,
      "fields" => updated_fields
    })

    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => "data_frame", "value" => value}, ctx) do
    updated_fields = updates_for_data_frame(value, ctx)
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

    updated_operations =
      List.replace_at(ctx.assigns.operations, idx, updated_operation) |> update_data_options(ctx)

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})
    {:noreply, ctx}
  end

  def handle_event("update_field", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)

    updated_operations =
      put_in(ctx.assigns.operations, [Access.at(idx), field], parsed_value)
      |> update_data_options(ctx)

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})
    {:noreply, ctx}
  end

  def handle_event("add_inner_value", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)
    updated_value = get_in(ctx.assigns.operations, [Access.at(idx), field]) ++ [parsed_value]

    updated_operations =
      put_in(ctx.assigns.operations, [Access.at(idx), field], updated_value)
      |> update_data_options(ctx)

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})
    {:noreply, ctx}
  end

  def handle_event("remove_inner_value", fields, ctx) do
    {field, value, idx} = {fields["field"], fields["value"], fields["idx"]}
    parsed_value = parse_value(field, value)

    updated_value =
      get_in(ctx.assigns.operations, [Access.at(idx), field]) |> List.delete(parsed_value)

    updated_operations =
      put_in(ctx.assigns.operations, [Access.at(idx), field], updated_value)
      |> update_data_options(ctx)

    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})
    {:noreply, ctx}
  end

  def handle_event("add_operation", %{"operation_type" => operation_type, "idx" => idx}, ctx) do
    new_operation = operation_type |> String.to_existing_atom() |> default_operation()

    updated_operations =
      List.insert_at(ctx.assigns.operations, idx, new_operation) |> update_data_options(ctx)

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

    updated_operations = update_data_options(updated_operations, ctx)
    ctx = assign(ctx, operations: updated_operations)
    broadcast_event(ctx, "set_operations", %{"operations" => updated_operations})

    {:noreply, ctx}
  end

  def handle_event("move_operation", %{"removedIndex" => remove, "addedIndex" => add}, ctx) do
    {operation, operations} = List.pop_at(ctx.assigns.operations, remove)
    updated_operations = List.insert_at(operations, add, operation) |> update_data_options(ctx)
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

  defp updates_for_data_frame(data_frame, ctx) do
    %{
      root_fields: %{
        "data_frame" => data_frame,
        "assign_to" => nil,
        "lazy" => true,
        "collect" => false
      },
      operations: default_operations() |> update_data_options(ctx, data_frame)
    }
  end

  defp updates_for_grouped_fields(:summarise, field, value, idx, ctx) do
    current_summarise = get_in(ctx.assigns.operations, [Access.at(idx)])
    columns = if field == "query", do: [], else: current_summarise["columns"]
    Map.merge(current_summarise, %{field => value, "columns" => columns})
  end

  defp updates_for_grouped_fields(:fill_missing, field, value, idx, ctx) do
    current_fill = get_in(ctx.assigns.operations, [Access.at(idx)])
    column = if field == "column", do: value, else: current_fill["column"]
    data_options = current_fill["data_options"] || %{}
    type = Map.get(data_options, column) || "string"
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
        "message" => message,
        "data_options" => data_options
      }
    else
      Map.merge(current_fill, %{field => value, "message" => message})
    end
  end

  defp updates_for_grouped_fields(:filters, field, value, idx, ctx) do
    current_filter = get_in(ctx.assigns.operations, [Access.at(idx)])
    column = if field == "column", do: value, else: current_filter["column"]
    data_options = current_filter["data_options"] || %{}
    type = Map.get(data_options, column) || "string"
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
        "operation_type" => "filters",
        "datalist" => current_filter["datalist"] || [],
        "data_options" => data_options
      }
    else
      Map.merge(current_filter, %{field => value, "message" => message})
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
    |> Map.put("missing_require", ctx.assigns.missing_require)
    |> Map.put("is_data_frame", is_data_frame?(ctx))
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
      |> Enum.filter(& &1.args)

    idx = collect_index(nodes, length(nodes), 0)

    nodes =
      nodes
      |> maybe_build_df(attrs)
      |> lazy(attrs)
      |> maybe_collect(attrs, idx)
      |> maybe_clean_up(attrs)

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
      for summarize <- summarization,
          column <- summarize.columns,
          summarize.query,
          summarize.active do
        {String.to_atom("#{column}_#{summarize.query}"),
         quote do
           unquote(summarize.query)(unquote(quoted_column(column)))
         end}
      end
      |> then(fn args -> if args != [], do: [args] end)

    %{field: :summarise, name: :summarise, args: summarize_args}
  end

  defp to_quoted([%{operation_type: operation_type} | _] = operations)
       when operation_type in @multiselect_operations do
    operation_args =
      for operation <- operations, operation.columns, operation.active do
        operation.columns
      end
      |> List.flatten()
      |> build_multiselect()

    %{field: operation_type, name: operation_type, args: operation_args}
  end

  defp to_quoted([
         %{operation_type: :pivot_wider, names_from: names, values_from: values, active: active}
       ]) do
    pivot_wider_args = if names && values && active, do: build_pivot_wider(names, values)
    %{field: :pivot_wider, name: :pivot_wider, args: pivot_wider_args}
  end

  defp maybe_build_df(nodes, %{is_data_frame: true}), do: nodes
  defp maybe_build_df(nodes, attrs), do: [build_df(attrs.data_frame_alias) | nodes]

  defp lazy(nodes, %{is_data_frame: false}), do: nodes
  defp lazy(nodes, attrs), do: [build_lazy(attrs.data_frame_alias) | nodes]

  defp maybe_collect(nodes, %{collect: false}, nil), do: nodes

  defp maybe_collect(nodes, %{collect: true} = attrs, nil) do
    nodes ++ [build_collect(attrs.data_frame_alias)]
  end

  defp maybe_collect(nodes, %{data_frame_alias: data_frame_alias}, idx) do
    {lazy, collected} = Enum.split(nodes, idx + 1)
    lazy ++ [build_collect(data_frame_alias)] ++ collected
  end

  defp maybe_collect(nodes, _, _), do: nodes

  defp maybe_clean_up([%{args: [[lazy: true]]} = new, %{field: :collect} | nodes], _) do
    [%{new | args: []} | nodes]
  end

  defp maybe_clean_up([%{field: :to_lazy}, %{field: :collect} | nodes], _), do: nodes

  defp maybe_clean_up(nodes, _) do
    if Enum.all?(nodes, &(!&1.args || &1.args == [])), do: [], else: nodes
  end

  defp build_root(df) do
    quote do
      unquote(Macro.var(String.to_atom(df), nil))
    end
  end

  defp build_df(module) do
    %{args: [[lazy: true]], field: :new, module: module, name: :new}
  end

  defp build_lazy(module) do
    %{args: [], field: :to_lazy, module: module, name: :to_lazy}
  end

  defp build_collect(module) do
    %{args: [], field: :collect, module: module, name: :collect}
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

  defp build_multiselect([]), do: nil
  defp build_multiselect([columns]), do: [columns]
  defp build_multiselect(columns), do: [columns]

  defp build_filter([column, filter, "quantile(" <> <<value::bytes-size(1)>> <> ")", type]) do
    build_filter([column, filter, "quantile(0#{value})", type])
  end

  defp build_filter([column, filter, "quantile(" <> <<value::bytes-size(2)>> <> ")", _] = args) do
    with true <- Enum.all?(args, &(&1 != nil)),
         {:ok, filter_value} <- cast_typed_value("integer", value) do
      {String.to_atom(filter), [],
       [
         quoted_column(column),
         quote do
           quantile(unquote(quoted_column(column)), unquote(filter_value / 100))
         end
       ]}
    else
      _ -> nil
    end
  end

  defp build_filter([column, filter, value, type] = args) when is_queried(type, value) do
    if Enum.all?(args, &(&1 != nil)) do
      {String.to_atom(filter), [],
       [
         quoted_column(column),
         quote do
           unquote(String.to_atom(value))(unquote(quoted_column(column)))
         end
       ]}
    else
      nil
    end
  end

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
      "operation_type" => "filters",
      "datalist" => []
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
    %{"columns" => [], "active" => true, "operation_type" => "group_by"}
  end

  defp default_operation(:summarise) do
    %{"columns" => [], "query" => nil, "active" => true, "operation_type" => "summarise"}
  end

  defp default_operation(:discard) do
    %{"columns" => [], "active" => true, "operation_type" => "discard"}
  end

  defp cast_typed_value("boolean", "true"), do: {:ok, true}
  defp cast_typed_value("boolean", "false"), do: {:ok, false}
  defp cast_typed_value("boolean", _), do: nil

  defp cast_typed_value("integer", value) do
    case Integer.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_typed_value("float", value) do
    case Float.parse(value) do
      {value, _} -> {:ok, value}
      _ -> nil
    end
  end

  defp cast_typed_value(type, value)
       when type in ["date", "datetime[ms]", "datetime[μs]", "datetime[ns]"],
       do: to_date(type, value)

  defp cast_typed_value("time", value), do: to_time(value)
  defp cast_typed_value(_, value), do: {:ok, value}

  defp to_date("date", value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> nil
    end
  end

  defp to_date("datetime" <> _, value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> nil
    end
  end

  defp to_time(value) do
    case Time.from_iso8601(value) do
      {:ok, time} -> {:ok, time}
      _ -> nil
    end
  end

  defp validation_message(:filters, _type, "quantile" <> _rest = quantile) do
    with %{"value" => value} <- Regex.named_captures(~r/quantile\((?<value>\d+)\)/, quantile),
         {:ok, value} <- cast_typed_value("integer", value),
         true <- value >= 0 and value <= 100 do
      nil
    else
      _ -> "should be between 0 and 100"
    end
  end

  defp validation_message(:filters, type, value) when is_queried(type, value), do: nil

  defp validation_message(operation, type, value) when operation in @validation_by_type do
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
    |> normalize_group_by()
  end

  defp normalize_values_from(values) when is_list(values), do: values
  defp normalize_values_from(nil), do: []
  defp normalize_values_from(values), do: [values]

  defp normalize_group_by(operations) do
    Enum.map(
      operations,
      &Map.new(&1, fn {k, v} -> if k == "group_by", do: {"columns", v}, else: {k, v} end)
    )
  end

  defp update_data_options([operation], ctx, data_frame) do
    data_frames = ctx.assigns.data_frames
    df = Enum.find_value(data_frames, &(&1.variable == data_frame && Map.get(&1, :data)))

    data_options =
      case df do
        nil -> nil
        %DataFrame{} -> DataFrame.dtypes(df) |> normalize_dtypes()
        _ -> df |> DataFrame.new() |> DataFrame.dtypes() |> normalize_dtypes()
      end

    [Map.put(operation, "data_options", data_options)]
  end

  defp update_data_options(operations, ctx) do
    binding = ctx.assigns.binding

    offsets =
      Enum.chunk_by(operations, & &1["operation_type"])
      |> Enum.flat_map(&Enum.to_list(1..length(&1)))

    if binding != [] do
      for {operation, idx} <- Enum.with_index(operations) do
        # This will fail if there are invalid operations.
        # The rescue allows us to let it crash in the output without crashing the smart cell,
        # keeping the previous data_options synchronized
        try do
          offset = if operation["operation_type"] == "filters", do: 1, else: Enum.at(offsets, idx)

          partial_operations =
            if idx - offset >= 0 and idx > 0,
              do: Enum.slice(operations, 0..(idx - offset)),
              else: []

          df =
            to_partial_attrs(ctx, partial_operations)
            |> to_source()
            |> Code.eval_string(binding)
            |> elem(0)

          data_options = DataFrame.dtypes(df) |> normalize_dtypes()

          Map.put(operation, "data_options", data_options)
          |> maybe_update_datalist(df)
        rescue
          _ -> operation
        end
      end
    else
      operations
    end
  end

  def to_partial_attrs(ctx, partial_operations) do
    ctx.assigns.root_fields
    |> Map.put("operations", partial_operations)
    |> Map.put("data_frame_alias", Explorer.DataFrame)
    |> Map.put("missing_require", Explorer.DataFrame)
    |> Map.put("is_data_frame", is_data_frame?(ctx))
  end

  defp maybe_update_datalist(%{"operation_type" => "filters"} = operation, df) do
    if operation["active"] && operation["column"] && operation["type"] == "string" do
      datalist = df[operation["column"]] |> Series.distinct() |> Series.to_list()
      Map.put(operation, "datalist", datalist)
    else
      operation
    end
  end

  defp maybe_update_datalist(operation, _df), do: operation

  defp valid_data(%DataFrame{}), do: true

  defp valid_data(data) do
    try do
      DataFrame.new(data)
      true
    rescue
      _ ->
        false
    end
  end

  defp is_data_frame?(ctx) do
    df = ctx.assigns.root_fields["data_frame"]
    Map.get(ctx.assigns.data_frame_variables, df)
  end

  defp collect_index([%{name: :group_by}, %{name: :summarise} | rest], size, idx) do
    collect_index(rest, size, idx + 2)
  end

  defp collect_index([%{name: :group_by} | _], size, idx), do: if(idx < size - 1, do: idx + 1)
  defp collect_index([%{name: :pivot_wider}], _size, idx), do: idx
  defp collect_index([_ | rest], size, idx), do: collect_index(rest, size, idx + 1)
  defp collect_index([], _size, _idx), do: nil

  defp normalize_dtypes(map) do
    map
    |> Enum.map(fn
      {k, {:datetime, :millisecond}} -> {k, "datetime[ms]"}
      {k, {:datetime, :microsecond}} -> {k, "datetime[μs]"}
      {k, {:datetime, :nanosecond}} -> {k, "datetime[ns]"}
      {k, v} -> {k, Atom.to_string(v)}
    end)
    |> Enum.into(%{})
  end
end
