import { Card } from '@contifisc/ui';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-4 p-8">
      <Card>
        <h1 className="text-xl font-semibold text-slate-900">CONTIFISC Plataforma</h1>
        <p className="mt-2 text-sm text-slate-600">
          Fase 1: estrutura arquitetural em construção. Nenhuma Skill de negócio implementada
          ainda.
        </p>
      </Card>
    </main>
  );
}
