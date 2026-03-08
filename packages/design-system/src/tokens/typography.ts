/**
 * Typography tokens for HAPAI design system
 * Font families, sizes, and weights
 */

export const typography = {
  fontFamily: {
    sans: [
      'Inter',
      '-apple-system',
      'BlinkMacSystemFont',
      '"Segoe UI"',
      'Roboto',
      '"Helvetica Neue"',
      'Arial',
      'sans-serif',
    ],
    mono: [
      '"Fira Code"',
      '"Cascadia Code"',
      'Monaco',
      'Menlo',
      '"Courier New"',
      'monospace',
    ],
  },

  fontSize: {
    xs: ['12px', { lineHeight: '16px', letterSpacing: '0.5px' }],
    sm: ['14px', { lineHeight: '20px', letterSpacing: '0.25px' }],
    base: ['16px', { lineHeight: '24px', letterSpacing: '0px' }],
    lg: ['18px', { lineHeight: '28px', letterSpacing: '-0.5px' }],
    xl: ['20px', { lineHeight: '28px', letterSpacing: '-0.5px' }],
    '2xl': ['24px', { lineHeight: '32px', letterSpacing: '-0.5px' }],
    '3xl': ['30px', { lineHeight: '36px', letterSpacing: '-1px' }],
    '4xl': ['36px', { lineHeight: '44px', letterSpacing: '-1px' }],
  },

  fontWeight: {
    light: 300,
    normal: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
    extrabold: 800,
  },

  lineHeight: {
    none: 1,
    tight: 1.25,
    normal: 1.5,
    relaxed: 1.625,
    loose: 2,
  },

  // Typography scale for headings
  headings: {
    h1: {
      fontSize: '36px',
      fontWeight: 700,
      lineHeight: '44px',
    },
    h2: {
      fontSize: '30px',
      fontWeight: 700,
      lineHeight: '36px',
    },
    h3: {
      fontSize: '24px',
      fontWeight: 600,
      lineHeight: '32px',
    },
    h4: {
      fontSize: '20px',
      fontWeight: 600,
      lineHeight: '28px',
    },
    h5: {
      fontSize: '18px',
      fontWeight: 600,
      lineHeight: '26px',
    },
    h6: {
      fontSize: '16px',
      fontWeight: 600,
      lineHeight: '24px',
    },
  },

  body: {
    lg: {
      fontSize: '18px',
      fontWeight: 400,
      lineHeight: '28px',
    },
    base: {
      fontSize: '16px',
      fontWeight: 400,
      lineHeight: '24px',
    },
    sm: {
      fontSize: '14px',
      fontWeight: 400,
      lineHeight: '20px',
    },
    xs: {
      fontSize: '12px',
      fontWeight: 400,
      lineHeight: '16px',
    },
  },
};

export const fontFamily = typography.fontFamily;
export const fontSize = typography.fontSize;
export const fontWeight = typography.fontWeight;
