import React from 'react';

export default function Logo({ size = 48, className = '' }) {
  return (
    <svg 
      width={size} 
      height={size} 
      viewBox="0 0 120 120" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      style={{ display: 'inline-block', verticalAlign: 'middle' }}
    >
      {/* Chimney */}
      <rect 
        x="36" 
        y="30" 
        width="8" 
        height="22" 
        fill="currentColor" 
      />

      {/* Outer Roof (Thick Chevron) */}
      <path 
        d="M22,54 L58,18 L94,54 L88,60 L58,30 L28,60 Z" 
        fill="currentColor" 
      />

      {/* Inner Roof (Thick Chevron) */}
      <path 
        d="M38,65 L58,45 L78,65 L73,70 L58,55 L43,70 Z" 
        fill="currentColor" 
      />

      {/* Inner House Walls */}
      <rect x="42" y="67" width="5" height="31" fill="currentColor" />
      <rect x="73" y="67" width="5" height="31" fill="currentColor" />

      {/* Ground Line */}
      <rect x="15" y="98" width="90" height="4" rx="2" fill="currentColor" />

      {/* Window */}
      <rect x="54" y="61" width="12" height="12" fill="currentColor" />

      {/* Door (Frame border) */}
      <path 
        d="M52,98 V82 H68 V98" 
        stroke="currentColor" 
        strokeWidth="4" 
        fill="none"
        strokeLinecap="round"
        strokeLinejoin="round"
      />

      {/* Left Leaf Shape */}
      <path 
        d="M27,98 C18,88 18,72 27,65 C36,72 36,88 27,98 Z" 
        fill="currentColor" 
      />
      {/* Leaf center line */}
      <path 
        d="M27,65 V98" 
        stroke="var(--bg-card, #FFFFFF)" 
        strokeWidth="1.5" 
      />

      {/* Right Potted Plant */}
      {/* Pot */}
      <polygon 
        points="88,98 96,98 98,86 86,86" 
        fill="currentColor" 
      />
      {/* Plant Stems and Leaves */}
      <path 
        d="M92,86 C92,76 84,72 84,65 C88,65 91,72 92,78 Z" 
        fill="currentColor" 
      />
      <path 
        d="M92,86 C92,76 100,72 100,65 C96,65 93,72 92,78 Z" 
        fill="currentColor" 
      />
      <path 
        d="M92,86 C92,72 92,62 92,58 C90,62 89,68 92,76 Z" 
        fill="currentColor" 
      />
    </svg>
  );
}
