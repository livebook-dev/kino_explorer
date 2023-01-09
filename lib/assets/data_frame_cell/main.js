import * as Vue from "https://cdn.jsdelivr.net/npm/vue@3.2.26/dist/vue.esm-browser.prod.js";

export function init(ctx, payload) {
  ctx.importCSS("main.css"),
    ctx.importCSS(
      "https://fonts.googleapis.com/css2?family=Inter:wght@400;500&display=swap"
    );

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
      >
      <option
        v-for="option in options"
        :value="option.value || option"
        :selected="option.value === modelValue || option === modelValue"
      >{{ option.label || option }}</option>
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
    </div>
    `,
  };

  const Accordion = {
    name: "Accordion",
    data() {
      return {
        isOpen: true,
      }
    },
    props: {
      hasOperations: {
        type: Boolean,
        required: true,
      },
    },
    methods: {
      toggleAccordion() {
        this.isOpen = !this.isOpen;
      },
    },
    template: `
    <div class="wrapper" :class="{'wrapper--closed': !isOpen}" v-show="hasOperations">
      <div
        class="accordion-control"
        :aria-expanded="isOpen"
        :aria-controls="id"
      >
        <span v-if="!isOpen"><slot name="title" /></span>
        <span></span>
        <span>
          <button
            class="button button--sm"
            @click="toggleAccordion()"
            type="button"
          >
            <svg
              class="button-svg"
              :class="{
                'rotate-180': isOpen,
                'rotate-0': !isOpen,
              }"
              fill="currentColor"
              stroke="currentColor"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 16 10"
              aria-hidden="true"
            >
              <path
                d="M15 1.2l-7 7-7-7"
              />
            </svg>
          </button>
          <button
            class="button button--sm"
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
        </span>
      </div>
      <div v-show="isOpen">
        <slot name="content" />
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

  const app = Vue.createApp({
    components: { BaseSelect, BaseInput, Accordion, BaseButton },
    template: `
      <div class="app">
        <div class="box box-warning" v-if="missingDep">
          <p>
            To successfully run, you need to add the following dependency:
          </p>
          <pre><code>{{ missingDep }}</code></pre>
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
            </div>
            <div class="add-operation">
              <BaseButton label="Group" @add-operation="addOperation('groups')"/>
              <BaseButton label="Sorting" @add-operation="addOperation('sorting')"/>
              <BaseButton label="Filter" @add-operation="addOperation('filters')"/>
            </div>
            <div class="layers">
              <Accordion
                class="layer-wrapper"
                @remove-operation="removeOperation('groups')"
                :hasOperations="hasOperations('groups')"
              >
                <template v-slot:title>
                  Groups
                </template>
                <template v-slot:content>
                  <div class="row">
                    <BaseSelect v-for="(group, index) in operations.groups"
                      name="group_by"
                      operation="groups"
                      label="Group By"
                      v-model="group.group_by"
                      :options="dataFrameColumns"
                      :required
                      :index="index"
                      :disabled="noDataFrame"
                    />
                  </div>
                </template>
              </Accordion>
            </div>
            <div class="layers">
              <Accordion
                class="layer-wrapper"
                v-for="(order, index) in operations.sorting"
                @remove-operation="removeOperation('sorting', index)"
                :hasOperations="hasOperations('sorting')"
              >
                <template v-slot:title>
                  Sorting
                </template>
                <template v-slot:content>
                  <div class="row">
                    <BaseSelect
                      name="order_by"
                      operation="sorting"
                      label="Order By"
                      v-model="order.order_by"
                      :options="dataFrameColumns"
                      :required
                      :index="index"
                      :disabled="noDataFrame"
                    />
                    <BaseSelect
                      name="order"
                      operation="sorting"
                      label="Order"
                      v-model="order.order"
                      :options="orderOptions"
                      :required
                      :index="index"
                      :disabled="noDataFrame"
                    />
                  </div>
                </template>
              </Accordion>
            </div>
            <div class="layers">
              <Accordion
                class="layer-wrapper"
                v-for="(filter, index) in operations.filters"
                @remove-operation="removeOperation('filters', index)"
                :hasOperations="hasOperations('filters')"
              >
                <template v-slot:title>
                </template>
                <template v-slot:content>
                  <div class="row">
                    <BaseSelect
                      name="column"
                      operation="filters"
                      label="Filter By"
                      v-model="filter.column"
                      :options="dataFrameColumns"
                      :required
                      :disabled="noDataFrame"
                      :index="index"
                    />
                    <BaseSelect
                      name="filter"
                      operation="filters"
                      label="Filter"
                      v-model="filter.filter"
                      :options="filterOptions.numeric"
                      :required
                      :disabled="noDataFrame"
                      :index="index"
                    />
                    <BaseInput
                      name="value"
                      operation="filters"
                      label="Value"
                      :index="index"
                      placeholder="Filter value"
                      v-model="filter.value"
                      :disabled="noDataFrame"
                      :required
                    />
                  </div>
                </template>
              </Accordion>
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
            { value: "less", label: "less" },
            { value: "less_equal", label: "less equal" },
            { value: "equal", label: "equal" },
            { value: "not_equal", label: "not equal" },
            { value: "greater_equal", label: "greater equal" },
            { value: "greater", label: "greater" },
          ],
          categorical: [
            { value: "equal", label: "equal" },
            { value: "contains", label: "contains" },
            { value: "not_equal", label: "not equal" },
          ],
          boolean: [
            { value: true, label: "true" },
            { value: false, label: "false" },
          ],
        }
      };
    },

    computed: {
      dataFrameColumns() {
        const dataFrameVariable = this.rootFields.data_frame;
        const dataFrame = this.dataFrames.find(
          (df) => df["variable"] === dataFrameVariable
        );
        return dataFrame ? dataFrame["columns"] : [];
      },
      // noDataFrame() {
      //   return !this.rootFields.data_frame;
      // },
    },

    methods: {
      handleFieldChange(event) {
        const field = event.target.name;
        const idx = event.target.getAttribute("index");
        const operation = event.target.getAttribute("operation");
        const value = idx
          ? this.operations[operation][idx][field]
          : this.rootFields[field];
        ctx.pushEvent("update_field", { operation, field, value, idx: idx && parseInt(idx) });
      },
      addOperation(operation) {
        ctx.pushEvent("add_operation", { operation });
      },
      removeOperation(operation, idx) {
        ctx.pushEvent("remove_operation", { operation, idx: parseInt(idx) });
      },
      hasOperations(operation) {
        return this.operations[operation].length > 0;
      },
    },
  }).mount(ctx.root);

  ctx.handleEvent("update_root", ({ fields }) => {
    setRootValues(fields);
  });

  ctx.handleEvent("update_operation", ({ operation, idx, fields})  => {
    setOperationValues(operation, idx, fields);
  });

  ctx.handleEvent("update_data_frame", ({ fields }) => {
    setOperations(fields.operations)
    setRootValues(fields.root_fields);
  });

  ctx.handleEvent("set_available_data", ({ data_options, fields }) => {
    app.dataFrameVariables = data_options.map((df) => df["variable"]);
    app.dataFrames = data_options;
    setOperations(fields.operations)
    setRootValues(fields.root_fields);
  });

  ctx.handleEvent("set_operations", (operations) => {
    setOperations(operations)
  });

  function setRootValues(fields) {
    for (const field in fields) {
      app.rootFields[field] = fields[field];
    }
  }

  function setOperationValues(operation, idx, fields) {
    for (const field in fields) {
      app.operations[operation][idx][field] = fields[field];
    }
  }

  function setOperations(operations) {
    for (const operation in operations) {
      app.operations[operation] = operations[operation];
    }
  }
}
