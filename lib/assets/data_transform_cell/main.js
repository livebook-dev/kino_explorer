export async function init(ctx, payload) {
  await importJS(
    "https://cdn.jsdelivr.net/npm/vue@3.2.37/dist/vue.global.prod.js"
  );
  await importJS(
    "https://cdn.jsdelivr.net/npm/vue-dndrop@1.2.13/dist/vue-dndrop.min.js"
  );
  ctx.importCSS(
    "https://fonts.googleapis.com/css2?family=Inter:wght@400;500&display=swap"
  );
  ctx.importCSS(
    "https://cdn.jsdelivr.net/npm/remixicon@3.2.0/fonts/remixicon.min.css"
  ),
  ctx.importCSS("main.css");

  const BaseSelect = {
    name: "BaseSelect",

    props: {
      label: {
        type: String,
        default: "",
      },
      selectClass: {
        type: String,
        default: "input",
      },
      modelValue: {
        type: String,
        default: "",
      },
      options: {
        type: Array,
        default: [],
        required: true,
      },
      required: {
        type: Boolean,
        default: false,
      },
      inline: {
        type: Boolean,
        default: false,
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    methods: {
      available(value, options) {
        return value
          ? options.some((option) => option === value || option.value === value)
          : true;
      },
    },
    template: `
    <div v-bind:class="inline ? 'inline-field' : 'field'">
      <label v-bind:class="inline ? 'inline-input-label' : 'input-label'">
        {{ label }}
      </label>
      <select
        :value="modelValue"
        v-bind="$attrs"
        v-bind:disabled="disabled"
        @change="$emit('update:modelValue', $event.target.value)"
        v-bind:class="selectClass"
        :class="{ unavailable: !available(modelValue, options) }"
      >
      <option v-if="!required && available(modelValue, options)"></option>
      <option
        v-for="option in options"
        :value="option.value || option"
        :selected="option.value === modelValue || option === modelValue"
      >{{ option.label || option }}</option>
      <option
        v-if="!available(modelValue, options)"
        class="unavailable-option"
        :value="modelValue"
      >{{ modelValue }}</option>
      </select>
    </div>
    `,
  };

  const BaseInput = {
    name: "BaseInput",

    props: {
      label: {
        type: String,
        default: "",
      },
      message: {
        type: String,
        default: "",
      },
      inputClass: {
        type: String,
        default: "input",
      },
      modelValue: {
        type: [String, Number],
        default: "",
      },
      inline: {
        type: Boolean,
        default: false,
      },
      grow: {
        type: Boolean,
        default: false,
      },
    },

    template: `
    <div v-bind:class="[inline ? 'inline-field' : 'field', grow ? 'grow' : '']">
      <label v-bind:class="inline ? 'inline-input-label' : 'input-label'">
        {{ label }}
      </label>
      <input
        :value="modelValue"
        @input="$emit('update:modelValue', $event.target.value)"
        v-bind="$attrs"
        v-bind:class="inputClass"
      >
      <div class="validation-wrapper">
        <span class="tooltip right validation-message" :data-tooltip="message" v-if="message">
          <i class="ri-error-warning-fill validation-icon"></i>
        </span>
      </div>
    </div>
    `,
  };

  const BaseCard = {
    name: "BaseCard",
    data() {
      return {
        isOpen: true,
      };
    },
    template: `
    <div class="card">
      <div class="card-content">
        <slot name="move" />
        <slot name="content" />
      </div>
      <div class="card-buttons">
        <div class="operation-controls">
          <slot name="toggle"/>
          <button
            class="button button--sm icon-only"
            @click="$emit('removeOperation')"
            type="button"
          >
            <i class="ri-delete-bin-line button-svg"></i>
          </button>
        </div>
        <div class="card-controls">
          <slot name="controls"></slot>
        </div>
      </div>
    </div>
  `,
  };

  const BaseButton = {
    name: "BaseButton",
    props: {
      label: {
        type: String,
        default: "",
      },
    },
    template: `
    <button class="button button--sm button--dashed" type="button" :disabled="noDataFrame"
      @click="$emit('addOperation')">
      <i class="ri-add-line"></i>
      <span class="dashed-button-label">{{ label }}</span>
    </button>
    `,
  };

  const BaseSwitch = {
    props: {
      label: {
        type: String,
        default: "",
      },
      modelValue: {
        type: Boolean,
      },
      fieldClass: {
        type: String,
        default: "field",
      },
      switchClass: {
        type: String,
        default: "default",
      },
    },
    template: `
        <div :class="[inner ? 'inner-field' : fieldClass]">
          <label class="input-label"> {{ label }} </label>
          <div class="input-container">
            <label class="switch-button">
              <input
                :checked="modelValue"
                type="checkbox"
                @input="$emit('update:modelValue', $event.target.checked)"
                v-bind="$attrs"
                :class="['switch-button-checkbox', switchClass]"
              >
              <div :class="['switch-button-bg', switchClass]" />
            </label>
          </div>
        </div>
      `,
  };

  const BaseMultiTagSelect = {
    name: "BaseMultiTagSelect",

    props: {
      label: {
        type: String,
        default: "",
      },
      message: {
        type: String,
        default: "",
      },
      selectClass: {
        type: String,
        default: "input",
      },
      modelValue: {
        type: String,
        default: "",
      },
      options: {
        type: Array,
        default: [],
        required: true,
      },
      required: {
        type: Boolean,
        default: false,
      },
      inline: {
        type: Boolean,
        default: false,
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    methods: {
      availableOptions(tags, options) {
        return options.filter((option) => !tags.includes(option));
      },
    },
    template: `
    <div v-bind:class="[inline ? 'inline-field' : 'field', 'multiselect']">
      <label v-bind:class="inline ? 'inline-input-label' : 'input-label'">
        {{ label }}
      </label>
      <div class="tags input">
        <div class="tags-wrapper">
          <span class="tag-message" v-if="disabled">{{ message }}</span>
          <span class="tag-pill" v-for="tag in modelValue">
            {{ tag }}
            <button
              class="button button--sm icon-only tag-button"
              @click="$emit('removeInnerValue', tag)"
              type="button"
            >
              <i class="tag-svg ri-close-line ri-xs"></i>
            </button>
          </span>
        </div>
        <select
          :value="modelValue"
          v-bind="$attrs"
          v-bind:disabled="disabled"
          v-bind:class="[selectClass, 'tag-input']"
        >
          <option disabled></option>
          <option
            v-for="option in availableOptions(modelValue, options)"
            :value="option.value || option"
            :selected=""
          >
            {{ option.label || option }}
          </option>
        </select>
      </div>
    </div>
    `,
  };

  const BaseDataList = {
    name: "BaseDataList",

    props: {
      label: {
        type: String,
        default: "",
      },
      message: {
        type: String,
        default: "",
      },
      datalist: {
        type: String,
        default: "datalist",
      },
      inputClass: {
        type: String,
        default: "input",
      },
      modelValue: {
        type: [String, Number],
        default: "",
      },
      options: {
        type: Array,
        default: [],
        required: true,
      },
      required: {
        type: Boolean,
        default: false,
      },
      inline: {
        type: Boolean,
        default: false,
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    template: `
    <div v-bind:class="inline ? 'inline-field' : 'field'">
      <label v-bind:class="inline ? 'inline-input-label' : 'input-label'">
        {{ label }}
      </label>
      <input
        :list="datalist"
        :value="modelValue"
        @input="$emit('update:modelValue', $event.target.value)"
        v-bind="$attrs"
        v-bind:class="inputClass"
      >
      <datalist :id="datalist">
        <option v-for="option in options" :value="option">
          {{ option }}
        </option>
      </datalist>
      <div class="validation-wrapper">
        <span class="tooltip right validation-message" :data-tooltip="message" v-if="message">
          <i class="ri-error-warning-fill validation-icon"></i>
        </span>
      </div>
    </div>
    `,
  };

  const app = Vue.createApp({
    components: {
      BaseSelect,
      BaseInput,
      BaseCard,
      BaseButton,
      BaseSwitch,
      BaseMultiTagSelect,
      BaseDataList,
      Container: VueDndrop.Container,
      Draggable: VueDndrop.Draggable,
    },
    template: `
      <div class="app">
        <!-- Info Messages -->
        <div class="box box-warning" v-if="noDataFrame">
          <p>The Data Transform smart cells works with Explorer DataFrames but none was found.</p>
          <p>To get started quickly, you might run the following on a previous cell:</p>
          <pre><code>iris = Explorer.Datasets.iris()</code></pre>
        </div>
        <!-- Data Frame Form -->
        <form @change="handleFieldChange">
          <div class="container">
            <div class="root">
              <BaseSelect
                name="data_frame"
                label="Data"
                v-model="rootFields.data_frame"
                :options="dataFrameVariables"
                :required
                :disabled="noDataFrame"
                class="root-field"
              />
              <BaseInput
                name="assign_to"
                label="Assign to"
                v-model="rootFields.assign_to"
                :disabled="noDataFrame"
                class="root-field"
              />
            </div>
            <!-- Operations -->
            <div class="pipeline">
              <div class="data-frame-title" v-if="isDataFrame">{{ rootFields.data_frame}}</div>
              <div class="data-frame-title" v-else>
                {{dataFrameAlias +  ".new(" + rootFields.data_frame + ")"}}
              </div>
              <Container @drop="handleItemDrop" lock-axis="y" non-drag-area-selector=".field">
                <Draggable
                  v-for="(operation, index) in operations"
                  :drag-not-allowed="operation.operation_type === 'pivot_wider'"
                >
                  <div :class="['operations', operation.operation_type, isGrouped(index) ? 'grouped' : '']">
                    <BaseCard
                      :class="operation.operation_type"
                      @remove-operation="removeOperation(operation.operation_type, index)"
                    >
                      <template
                        v-slot:move
                        v-if="operation.operation_type !== 'pivot_wider' && operation.operation_type !== 'summarise'"
                      >
                        <i class="ri-draggable button-svg drag-move"></i>
                      </template>
                      <template v-slot:content>
                        <div class="row" v-if="operation.operation_type === 'filters'">
                          <BaseSelect
                            name="column"
                            operation_type="filters"
                            label="Filter by"
                            v-model="operation.column"
                            :options="dataFrameColumnsWithTypes(operation.data_options)"
                            :disabled="noDataFrame"
                            :index="index"
                          />
                          <BaseSelect
                            name="filter"
                            operation_type="filters"
                            label="Operation"
                            v-model="operation.filter"
                            :options="filterOptionsByType(operation.column, operation.data_options)"
                            :required
                            :disabled="!operation.column"
                            :index="index"
                          />
                          <BaseSelect
                            v-if="operation.type === 'boolean'"
                            name="value"
                            operation_type="filters"
                            label="Value"
                            v-model="operation.value"
                            :options="['true', 'false']"
                            :required
                            :disabled="!operation.column"
                            :index="index"
                          />
                          <template v-else>
                            <BaseDataList
                              v-if="operation.type === 'string'"
                              name="value"
                              operation_type="filters"
                              label="Value"
                              :index="index"
                              :options="operation.datalist"
                              placeholder="Filter value"
                              v-model="operation.value"
                              :disabled="!operation.column"
                              :required
                              :datalist="'filers_' + index"
                            />
                            <BaseDataList
                              v-else-if="isQueriedFilter(operation.type)"
                              name="value"
                              operation_type="filters"
                              label="Value"
                              :message="operation.message"
                              :index="index"
                              placeholder="Filter value"
                              v-model="operation.value"
                              :options="queriedFilterOptions"
                              :disabled="!operation.column"
                              :required
                              :datalist="'filers_' + index"
                            />
                            <BaseInput
                              v-else
                              name="value"
                              operation_type="filters"
                              label="Value"
                              :message="operation.message"
                              :index="index"
                              placeholder="Filter value"
                              v-model="operation.value"
                              :disabled="!operation.column"
                              :required
                            />
                          </template>
                        </div>
                        <div class="row" v-if="operation.operation_type === 'fill_missing'">
                          <BaseSelect
                            name="column"
                            operation_type="fill_missing"
                            label="Fill missing"
                            v-model="operation.column"
                            :options="dataFrameColumns(operation.data_options)"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseSelect
                            name="strategy"
                            operation_type="fill_missing"
                            label="With"
                            v-model="operation.strategy"
                            :options="fillMissingOptionsByType(operation.column, operation.data_options)"
                            :required
                            :index="index"
                            :disabled="!operation.column"
                          />
                          <template v-if="operation.strategy === 'scalar'">
                            <BaseSelect
                              v-if="operation.type === 'boolean'"
                              name="scalar"
                              operation_type="fill_missing"
                              label="Value"
                              v-model="operation.scalar"
                              :options="['true', 'false']"
                              :required
                              :disabled="!operation.column"
                              :index="index"
                            />
                            <BaseInput
                              v-else
                              name="scalar"
                              operation_type="fill_missing"
                              label="Value"
                              :message="operation.message"
                              :index="index"
                              placeholder="Fill missing value"
                              v-model="operation.scalar"
                              :disabled="!operation.column"
                              :required
                            />
                          </template>
                        </div>
                        <div class="row" v-if="operation.operation_type === 'sorting'">
                          <BaseSelect
                            name="sort_by"
                            operation_type="sorting"
                            label="Sort by"
                            v-model="operation.sort_by"
                            :options="dataFrameColumns(operation.data_options)"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseSelect
                            name="direction"
                            operation_type="sorting"
                            label="Direction"
                            v-model="operation.direction"
                            :options="orderOptions"
                            :required
                            :index="index"
                            :disabled="!operation.sort_by"
                          />
                        </div>
                        <div class="row" v-if="operation.operation_type === 'group_by'">
                          <BaseMultiTagSelect
                            @change.self="addInnerValue($event)"
                            operation_type="group_by"
                            label="Group by"
                            v-model="operation.columns"
                            :options="dataFrameColumns(operation.data_options)"
                            :index="index"
                            field="columns"
                            :disabled="noDataFrame"
                            @remove-inner-value="removeInnerValue(index, 'columns', $event)"
                          />
                        </div>
                        <div class="row" v-if="operation.operation_type === 'summarise'">
                          <BaseSelect
                            name="query"
                            operation_type="summarise"
                            label="Summarise using"
                            v-model="operation.query"
                            :options="summariseUsingOptions"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseMultiTagSelect
                            @change.self="addInnerValue($event)"
                            operation_type="summarise"
                            label="Of columns"
                            v-model="operation.columns"
                            :options="dataFrameColumnsByTypes(summariseOptions[operation.query], operation.data_options)"
                            :index="index"
                            field="columns"
                            :disabled="!operation.query"
                            @remove-inner-value="removeInnerValue(index, 'columns', $event)"
                            message="Select 'Summarise using' first"
                          />
                        </div>
                        <div class="row" v-if="operation.operation_type === 'pivot_wider'">
                          <BaseSelect
                            name="names_from"
                            operation_type="pivot_wider"
                            label="Pivot names from"
                            v-model="operation.names_from"
                            :options="dataFrameColumnsByTypes(pivotWiderTypes.names_from, operation.data_options)"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseMultiTagSelect
                            @change.self="addInnerValue($event)"
                            operation_type="pivot_wider"
                            label="Values from"
                            v-model="operation.values_from"
                            :options="dataFrameColumnsByTypes(pivotWiderTypes.values_from, operation.data_options)"
                            :index="index"
                            field="values_from"
                            :disabled="noDataFrame"
                            @remove-inner-value="removeInnerValue(index, 'values_from', $event)"
                          />
                        </div>
                        <div class="row" v-if="operation.operation_type === 'discard'">
                          <BaseMultiTagSelect
                            @change.self="addInnerValue($event)"
                            operation_type="discard"
                            label="Columns to discard"
                            v-model="operation.columns"
                            :options="dataFrameColumns(operation.data_options)"
                            :index="index"
                            field="columns"
                            :disabled="noDataFrame"
                            @remove-inner-value="removeInnerValue(index, 'columns', $event)"
                          />
                        </div>
                      </template>
                      <template v-slot:toggle>
                        <BaseSwitch
                          name="active"
                          :operation_type="operation.operation_type"
                          :index="index"
                          v-model="operation.active"
                          :disabled="noDataFrame"
                          fieldClass="switch-sm"
                          :switchClass="operation.operation_type"
                        />
                      </template>
                      <template v-slot:controls v-if="operation.operation_type !== 'pivot_wider'">
                        <button
                          class="button button--sm icon-only"
                          @click="addGroupedOperation(operation.operation_type, index + 1)"
                          type="button"
                        >
                        <i class="ri-file-copy-line button-svg"></i>
                        </button>
                      </template>
                    </BaseCard>
                  </div>
                </Draggable>
              </Container>
            </div>
            <div class="add-operation">
              <BaseButton label="Discard" @add-operation="addOperation('discard')" :disabled="noDataFrame || noAvailableData"/>
              <BaseButton label="Fill missing" @add-operation="addOperation('fill_missing')" :disabled="noDataFrame || noAvailableData"/>
              <BaseButton label="Filter" @add-operation="addOperation('filters')" :disabled="noDataFrame || noAvailableData"/>
              <BaseButton label="Group" @add-operation="addOperation('group_by')" :disabled="noDataFrame || noAvailableData"/>
              <BaseButton
                :disabled="hasOperation('pivot_wider') || noDataFrame || noAvailableData"
                label="Pivot wider"
                @add-operation="addOperation('pivot_wider')"
              />
              <BaseButton label="Sort" @add-operation="addOperation('sorting')" :disabled="noDataFrame || noAvailableData"/>
              <BaseButton
                label="Summarise"
                @add-operation="addOperation('summarise')"
                :disabled="!hasValidGroups || noDataFrame ||noAvailableData"
              />
            </div>
          </div>
        </form>
      </div>
    `,

    data() {
      return {
        rootFields: payload.root_fields,
        operations: payload.operations,
        dataFrameVariables: Object.keys(payload.data_frame_variables),
        dataFrames: payload.data_frame_variables,
        dataFrameAlias: payload.data_frame_alias.slice(7),
        pivotWiderTypes: payload.operation_types.pivot_wider,
        summariseTypes: payload.operation_types.summarise,
        queriedFilterTypes: payload.operation_types.queried_filter,
        fillMissingOptions: payload.operation_options.fill_missing,
        filterOptions: payload.operation_options.filter,
        queriedFilterOptions: payload.operation_options.queried_filter,
        summariseOptions: payload.operation_options.summarise,
        summariseUsingOptions: Object.keys(payload.operation_options.summarise),
        orderOptions: [
          { label: "ascending", value: "asc" },
          { label: "descending", value: "desc" },
        ],
      };
    },

    computed: {
      isDataFrame() {
        return this.dataFrames[this.rootFields.data_frame];
      },
      noDataFrame() {
        return !this.rootFields.data_frame;
      },
      noAvailableData() {
        const dataFrame = this.rootFields.data_frame;
        return dataFrame ? !this.dataFrameVariables.includes(dataFrame) : true;
      },
      hasValidGroups() {
        const groups = this.operations.find(
          (operation) => operation.operation_type === "group_by"
        );
        return groups ? groups.columns.length > 0 : false;
      },
    },

    methods: {
      dataFrameColumns(data_options) {
        return data_options ? Object.keys(data_options) : [];
      },
      dataFrameColumnsWithTypes(data_options) {
        const dataFrameColumns = data_options
          ? Object.entries(data_options)
          : {};
        const columns = Array.from(dataFrameColumns, ([name, type]) => {
          return { label: `${name} (${type})`, value: name };
        });
        return columns;
      },
      hasOperation(operation_type) {
        return this.operations.some(
          (operation) => operation.operation_type === operation_type
        );
      },
      handleFieldChange(event) {
        const field = event.target.name;
        if (!field) return;
        const idx = event.target.getAttribute("index");
        const operation_type = event.target.getAttribute("operation_type");
        const value = idx
          ? this.operations[idx][field]
          : this.rootFields[field];
        ctx.pushEvent("update_field", {
          operation_type,
          field,
          value,
          idx: idx && parseInt(idx),
        });
      },
      addOperation(operation_type) {
        ctx.pushEvent("add_operation", { operation_type });
      },
      addGroupedOperation(operation_type, idx) {
        ctx.pushEvent("add_operation", { operation_type, idx });
      },
      removeOperation(operation_type, idx) {
        ctx.pushEvent("remove_operation", {
          operation_type,
          idx: parseInt(idx),
        });
      },
      isQueriedFilter(type) {
        return this.queriedFilterTypes.includes(type);
      },
      filterOptionsByType(column, data_options) {
        const columnType = data_options ? data_options[column] : null;
        return columnType ? this.filterOptions[columnType] : [];
      },
      fillMissingOptionsByType(column, data_options) {
        const columnType = data_options ? data_options[column] : null;
        return columnType ? this.fillMissingOptions[columnType] : [];
      },
      dataFrameColumnsByTypes(columnTypes, data_options) {
        const supportedTypes = columnTypes ? columnTypes : [];
        const dataFrameColumns = data_options ? data_options : {};
        const supportedColumns = Object.entries(dataFrameColumns)
          .filter(([col, type]) => supportedTypes.includes(type))
          .map(([col, type]) => col);
        return supportedColumns;
      },
      handleItemDrop({ removedIndex, addedIndex }) {
        const offset = this.operations.filter(
          (operation) => operation.operation_type === "pivot_wider"
        ).length;
        const maxAllowed = this.operations.length - offset - 1;
        addedIndex = Math.min(addedIndex, maxAllowed);
        if (removedIndex === addedIndex) return;
        ctx.pushEvent("move_operation", { removedIndex, addedIndex });
      },
      addInnerValue(event) {
        const value = event.target.value;
        const field = event.target.getAttribute("field");
        const idx = event.target.getAttribute("index");
        const operation_type = event.target.getAttribute("operation_type");
        ctx.pushEvent("add_inner_value", {
          operation_type,
          field,
          value,
          idx: parseInt(idx),
        });
      },
      removeInnerValue(idx, field, value) {
        ctx.pushEvent("remove_inner_value", {
          field,
          value,
          idx: parseInt(idx),
        });
      },
      isGrouped(index) {
        const operationType = this.operations[index].operation_type;
        if (index < this.operations.length - 1) {
          return this.operations[index + 1].operation_type === operationType;
        } else {
          return false;
        }
      },
    },
  }).mount(ctx.root);

  ctx.handleEvent("update_root", ({ fields }) => {
    setRootValues(fields);
  });

  ctx.handleEvent("update_data_frame", ({ fields }) => {
    setOperations(fields.operations);
    setRootValues(fields.root_fields);
  });

  ctx.handleEvent("set_available_data", ({ data_frame_variables, data_frame_alias, fields }) => {
    app.dataFrameVariables = Object.keys(data_frame_variables);
    app.dataFrames = data_frame_variables;
    app.dataFrameAlias = data_frame_alias.slice(7);
    setRootValues(fields.root_fields);
    setOperations(fields.operations);
  });

  ctx.handleEvent("set_operations", ({ operations }) => {
    setOperations(operations);
  });

  function setRootValues(fields) {
    for (const field in fields) {
      app.rootFields[field] = fields[field];
    }
  }

  function setOperations(operations) {
    app.operations = operations;
  }
}

// Imports a JS script globally using a <script> tag
function importJS(url) {
  return new Promise((resolve, reject) => {
    const scriptEl = document.createElement("script");
    scriptEl.addEventListener(
      "load",
      (event) => {
        resolve();
      },
      { once: true }
    );
    scriptEl.src = url;
    document.head.appendChild(scriptEl);
  });
}
