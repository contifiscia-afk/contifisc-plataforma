import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'CONTIFISC Plataforma',
  description: 'Fase 1 — estrutura arquitetural, sem Skills de negócio.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
