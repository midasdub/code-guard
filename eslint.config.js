const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  js.configs.recommended,
  {
    // Lint every JavaScript flavour, not only .js: an agent could hide
    // code in a .cjs or .mjs file to escape a "**/*.js" pattern.
    files: ["**/*.{js,cjs,mjs}"],
    languageOptions: {
      ecmaVersion: "latest",
      globals: globals.node
    },
    rules: {
      // --- SECURITY RULES (Combating suspicious code) ---

      // Forbids the use of eval(). This is critical, as the agent might
      // try to execute hidden code passed as a string.
      "no-eval": "error",

      // Forbids implied eval, e.g., setTimeout("console.log('hi')", 1000)
      "no-implied-eval": "error",

      // Forbids the Function constructor, which works the same way as eval()
      "no-new-func": "error",

      // Forbids bitwise operators unless necessary. Agents sometimes
      // use them to obfuscate logic.
      "no-bitwise": "warn",

      // --- CODE QUALITY RULES ---

      // Blocks code where a variable is declared but never used.
      // This is a common error in agent-generated code.
      "no-unused-vars": "error",

      // Forbids the use of undeclared variables (protection against agent typos)
      "no-undef": "error",

      // Forbids infinite or constant conditions (e.g., if (true))
      "no-constant-condition": "error"
    }
  },
  {
    files: ["**/*.{js,cjs}"],
    languageOptions: { sourceType: "commonjs" }
  }
];
