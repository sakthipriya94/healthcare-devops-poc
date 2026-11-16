import { useCallback, useEffect, useState } from "react";

const emptyForm = { mrn: "", first_name: "", last_name: "", date_of_birth: "" };

async function api(path, options) {
  const res = await fetch(`/api/${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(JSON.stringify(body));
  return body;
}

export default function App() {
  const [tenant, setTenant] = useState(null);
  const [patients, setPatients] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    try {
      setError("");
      setTenant(await api("tenant/"));
      setPatients(await api("patients/"));
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function submit(e) {
    e.preventDefault();
    try {
      setError("");
      await api("patients/", { method: "POST", body: JSON.stringify(form) });
      setForm(emptyForm);
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  return (
    <main>
      <header>
        <h1>{tenant ? tenant.name : "Healthcare Portal"}</h1>
        {tenant && (
          <span className="badge" title="Resolved from the sub-domain">
            tenant: {tenant.id} · region: {tenant.region}
          </span>
        )}
      </header>

      {error && <p className="error">{error}</p>}

      <section>
        <h2>Patients ({patients.length})</h2>
        <table>
          <thead>
            <tr>
              <th>MRN</th>
              <th>Name</th>
              <th>Date of birth</th>
            </tr>
          </thead>
          <tbody>
            {patients.map((p) => (
              <tr key={p.id}>
                <td>{p.mrn}</td>
                <td>
                  {p.last_name}, {p.first_name}
                </td>
                <td>{p.date_of_birth}</td>
              </tr>
            ))}
            {patients.length === 0 && (
              <tr>
                <td colSpan="3">No patients yet.</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>

      <section>
        <h2>Add patient</h2>
        <form onSubmit={submit}>
          <input placeholder="MRN" value={form.mrn} onChange={set("mrn")} required />
          <input placeholder="First name" value={form.first_name} onChange={set("first_name")} required />
          <input placeholder="Last name" value={form.last_name} onChange={set("last_name")} required />
          <input type="date" value={form.date_of_birth} onChange={set("date_of_birth")} required />
          <button type="submit">Add</button>
        </form>
      </section>
    </main>
  );
}
