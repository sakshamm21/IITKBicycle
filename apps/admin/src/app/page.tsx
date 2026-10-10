import { APP_NAME } from "@iitk-bicycle/shared";

export default function Home() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-3 p-8 text-center">
      <h1 className="text-4xl font-semibold tracking-tight">{APP_NAME}</h1>
      <p className="text-sm opacity-70">Admin console. Coming soon.</p>
    </main>
  );
}
