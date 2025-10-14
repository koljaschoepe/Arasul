import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  extensionsToTreatAsEsm: ['.ts'],
  transform: { '^.+\\.(ts|tsx)$': ['ts-jest', { useESM: true }] },
  globals: {
    'ts-jest': {
      useESM: true,
      tsconfig: {
        module: 'Node16',
        moduleResolution: 'Node16',
      },
    },
  },
  moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' },
};

export default config;
