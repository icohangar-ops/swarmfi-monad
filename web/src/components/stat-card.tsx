export function StatCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-5">
      <p className="text-xs uppercase tracking-wider text-violet-400">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-white">{value}</p>
      {hint ? <p className="mt-1 text-xs text-violet-300/70">{hint}</p> : null}
    </div>
  );
}
