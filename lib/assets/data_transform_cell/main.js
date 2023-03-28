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
        <svg class="validation-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
          <path fill="none" d="M0 0h24v24H0z"/>
          <path d="M12 22C6.477 22 2 17.523 2 12S6.477 2 12 2s10 4.477 10 10-4.477 10-10 10zm-1-7v2h2v-2h-2zm0-8v6h2V7h-2z"
          fill="#E2474D"/>
        </svg>
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
            <svg
              class="button-svg"
              fill="currentColor"
              stroke="none"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 16 16"
              aria-hidden="true"
            >
              <path
                d="M11.75 3.5H15.5V5H14V14.75C14 14.9489 13.921 15.1397 13.7803 15.2803C13.6397 15.421 13.4489
                15.5 13.25 15.5H2.75C2.55109 15.5 2.36032 15.421 2.21967 15.2803C2.07902 15.1397 2 14.9489 2
                14.75V5H0.5V3.5H4.25V1.25C4.25 1.05109 4.32902 0.860322 4.46967 0.71967C4.61032 0.579018 4.80109
                0.5 5 0.5H11C11.1989 0.5 11.3897 0.579018 11.5303 0.71967C11.671 0.860322 11.75 1.05109 11.75
                1.25V3.5ZM12.5 5H3.5V14H12.5V5ZM5.75 7.25H7.25V11.75H5.75V7.25ZM8.75
                7.25H10.25V11.75H8.75V7.25ZM5.75 2V3.5H10.25V2H5.75Z"
              />
            </svg>
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
      <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
        <path d="M4.41699 4.41602V0.916016H5.58366V4.41602H9.08366V5.58268H5.58366V9.08268H4.41699V5.58268H0.916992V4.41602H4.41699Z"/>
      </svg>
      {{ label }}
    </button>
    `,
  };

  const BaseInputIcon = {
    name: "BaseInputIcon",
    props: {
      label: {
        type: String,
        default: "",
      },
    },
    template: `
    <div class="icon-container" @click="$emit('removeOperation')">
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16">
        <path fill="none" d="M0 0h24v24H0z"/>
        <path d="M17 6h5v2h-2v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V8H2V6h5V3a1 1 0 0 1 1-1h8a1 1 0 0 1 1 1v3zm1 2H6v12h12V8zm-9 3h2v6H9v-6zm4 0h2v6h-2v-6zM9 4v2h6V4H9z"/>
      </svg>
    </div>
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
        return options.filter(option => !tags.includes(option));
      },
    },
    template: `
    <div v-bind:class="[inline ? 'inline-field' : 'field', 'multiselect']">
      <label v-bind:class="inline ? 'inline-input-label' : 'input-label'">
        {{ label }}
      </label>
      <div class="tags input">
        <div class="tags-wrapper">
          <span class="tag-pill" v-for="tag in modelValue">
            {{ tag }}
            <button
              class="button button--sm icon-only tag-button"
              @click="$emit('removeInnerValue', tag)"
              type="button"
            >
              <svg
                class="tag-svg"
                fill="currentColor"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                width="12"
                height="12"
              >
              <path fill="none" d="M0 0h24v24H0z"/>
              <path d="M12 10.586l4.95-4.95 1.414 1.414-4.95 4.95 4.95 4.95-1.414 1.414-4.95-4.95-4.95 4.95-1.414-1.414
              4.95-4.95-4.95-4.95L7.05 5.636z"/>
              </svg>
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

  const app = Vue.createApp({
    components: {
      BaseSelect,
      BaseInput,
      BaseCard,
      BaseButton,
      BaseInputIcon,
      BaseSwitch,
      BaseMultiTagSelect,
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
                label="Data Frame"
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
              <div class="data-frame-title">{{ rootFields.data_frame }}</div>
              <Container @drop="handleItemDrop" lock-axis="y" non-drag-area-selector=".field">
                <Draggable
                  v-for="(operation, index) in operations"
                  :drag-not-allowed="operation.operation_type === 'pivot_wider'"
                >
                  <div :class="['operations', operation.operation_type]">
                    <BaseCard
                      :class="operation.operation_type"
                      @remove-operation="removeOperation(operation.operation_type, index)"
                    >
                      <template v-slot:move v-if="operation.operation_type !== 'pivot_wider'">
                        <svg class="button-svg drag-move" fill="currentColor" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
                          <defs>
                            <path fill="none" d="M0 0h24v24H0z"/>
                            <path id="dots" d="M12 3c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 14c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9
                            2-2-.9-2-2-2zm0-7c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/>
                          </defs>
                          <use xlink:href="#dots" x="0" y="0" />
                          <use xlink:href="#dots" x="6" y="0" />
                        </svg>
                      </template>
                      <template v-slot:content>
                        <div class="row" v-if="operation.operation_type === 'filters'">
                          <BaseSelect
                            name="column"
                            operation_type="filters"
                            label="Filter by"
                            v-model="operation.column"
                            :options="dataFrameColumns"
                            :disabled="noDataFrame"
                            :index="index"
                          />
                          <BaseSelect
                            name="filter"
                            operation_type="filters"
                            label="Operation"
                            v-model="operation.filter"
                            :options="filterOptionsByType(operation.column)"
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
                        </div>
                        <div class="row" v-if="operation.operation_type === 'fill_missing'">
                          <BaseSelect
                            name="column"
                            operation_type="fill_missing"
                            label="Fill missing"
                            v-model="operation.column"
                            :options="dataFrameColumns"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseSelect
                            name="strategy"
                            operation_type="fill_missing"
                            label="With"
                            v-model="operation.strategy"
                            :options="fillMissingOptionsByType(operation.column)"
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
                            :options="dataFrameColumns"
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
                            v-model="operation.group_by"
                            :options="dataFrameColumns"
                            :index="index"
                            field="group_by"
                            :disabled="noDataFrame"
                            @remove-inner-value="removeInnerValue(index, 'group_by', $event)"
                          />
                        </div>
                        <div class="row" v-if="operation.operation_type === 'pivot_wider'">
                          <BaseSelect
                            name="names_from"
                            operation_type="pivot_wider"
                            label="Pivot names from"
                            v-model="operation.names_from"
                            :options="dataFrameColumnsByType('string')"
                            :index="index"
                            :disabled="noDataFrame"
                          />
                          <BaseMultiTagSelect
                            @change.self="addInnerValue($event)"
                            operation_type="pivot_wider"
                            label="Values from"
                            v-model="operation.values_from"
                            :options="dataFrameColumnsByType('integer')"
                            :index="index"
                            field="values_from"
                            :disabled="noDataFrame"
                            @remove-inner-value="removeInnerValue(index, 'values_from', $event)"
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
                        <svg
                          class="button-svg"
                          fill="currentColor"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          width="24"
                          height="24"
                        >
                          <path fill="none" d="M0 0h24v24H0z"/>
                          <path d="M7 6V3a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-3v3c0 .552-.45 1-1.007
                          1H4.007A1.001 1.001 0 0 1 3 21l.003-14c0-.552.45-1 1.007-1H7zM5.003 8L5 20h10V8H5.003zM9 6h8v10h2V4H9v2z"/>
                        </svg>
                        </button>
                      </template>
                    </BaseCard>
                  </div>
                </Draggable>
              </Container>
            </div>
            <div class="add-operation">
              <BaseButton label="Sorting" @add-operation="addOperation('sorting')" :disabled="noDataFrame"/>
              <BaseButton label="Filter" @add-operation="addOperation('filters')" :disabled="noDataFrame"/>
              <BaseButton label="Fill Missing" @add-operation="addOperation('fill_missing')" :disabled="noDataFrame"/>
              <BaseButton label="Group by" @add-operation="addOperation('group_by')" :disabled="noDataFrame"/>
              <BaseButton
                :disabled="hasPivotWider"
                label="Pivot Wider"
                @add-operation="addOperation('pivot_wider')"
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
        dataFrames: payload.data_options,
        dataFrameVariables: payload.data_options.map((df) => df["variable"]),
        orderOptions: [
          { label: "ascending", value: "asc" },
          { label: "descending", value: "desc" },
        ],
        filterOptions: {
          numeric: [
            "less",
            "less equal",
            "equal",
            "not equal",
            "greater equal",
            "greater",
          ],
          categorical: ["equal", "contains", "not equal"],
          boolean: ["equal", "not equal"],
        },
        columnTypes: {
          float: "numeric",
          integer: "numeric",
          date: "numeric",
          string: "categorical",
          boolean: "boolean",
        },
        fillMissingOptions: {
          string: ["forward", "backward", "max", "min", "scalar"],
          date: ["forward", "backward", "max", "min", "scalar"],
          boolean: ["forward", "backward", "max", "min", "scalar"],
          integer:  ["forward", "backward", "max", "min", "mean", "scalar"],
          float: ["forward", "backward", "max", "min", "mean", "nan", "scalar"],
        }
      };
    },

    computed: {
      dataFrameInfo() {
        const dataFrameVariable = this.rootFields.data_frame;
        const dataFrame = this.dataFrames.find(
          (df) => df["variable"] === dataFrameVariable
        );
        return dataFrame;
      },
      dataFrameColumns() {
        const dataFrame = this.dataFrameInfo;
        return dataFrame ? Object.keys(dataFrame["columns"]) : [];
      },
      noDataFrame() {
        return !this.rootFields.data_frame;
      },
      hasPivotWider() {
        return this.operations.some(
          (operation) => operation.operation_type === "pivot_wider"
        );
      },
    },

    methods: {
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
      filterOptionsByType(column) {
        const columnType = this.dataFrameInfo?.columns[column];
        return this.filterOptions[this.columnTypes[columnType]];
      },
      fillMissingOptionsByType(column) {
        const columnType = this.dataFrameInfo?.columns[column];
        return this.fillMissingOptions[columnType];
      },
      columnType(column) {
        return this.dataFrameInfo?.columns[column];
      },
      dataFrameColumnsByType(supportedType) {
        const dataFrameColumns = this.dataFrameInfo
          ? this.dataFrameInfo.columns
          : {};
        const supportedColumns = Object.entries(dataFrameColumns)
          .filter(([col, type]) => type === supportedType)
          .map(([col, type]) => col);
        return supportedColumns;
      },
      handleItemDrop({ removedIndex, addedIndex }) {
        const maxAllowed = this.hasPivotWider ? this.operations.length - 2 : this.operations.length - 1;
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
        ctx.pushEvent("remove_inner_value", { field, value, idx: parseInt(idx) })
      },
    },
  }).mount(ctx.root);

  ctx.handleEvent("update_root", ({ fields }) => {
    setRootValues(fields);
  });

  ctx.handleEvent("update_operation", ({ idx, fields }) => {
    setOperationValues(idx, fields);
  });

  ctx.handleEvent("update_data_frame", ({ fields }) => {
    setOperations(fields.operations);
    setRootValues(fields.root_fields);
  });

  ctx.handleEvent("set_available_data", ({ data_options, fields }) => {
    app.dataFrameVariables = data_options.map((df) => df["variable"]);
    app.dataFrames = data_options;
    setRootValues(fields.root_fields);
  });

  ctx.handleEvent("set_operations", ({ operations }) => {
    setOperations(operations);
  });

  function setRootValues(fields) {
    for (const field in fields) {
      app.rootFields[field] = fields[field];
    }
  }

  function setOperationValues(idx, fields) {
    for (const field in fields) {
      app.operations[idx][field] = fields[field];
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
