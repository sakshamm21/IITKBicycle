const env = {
  url: (typeof process !== "undefined" ? process.env.EXPO_PUBLIC_SUPABASE_URL : undefined)
    || (typeof process !== "undefined" ? process.env.NEXT_PUBLIC_SUPABASE_URL : undefined)
    || "https://jwyamfjoisycodwelpys.supabase.co",
  key: (typeof process !== "undefined" ? process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY : undefined)
    || (typeof process !== "undefined" ? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY : undefined)
    || "",
};

export type Session = { access_token: string; refresh_token?: string; user: { id: string; email?: string; user_metadata?: Record<string, unknown> } };
export type Profile = { id: string; college_id: string | null; full_name: string; phone: string | null; email: string; role: string; status: string; member_type: string };
export type Bike = { id: string; short_code: string; status: string; notes: string | null; stand_id: string | null };
export type Stand = { id: string; name: string; latitude: number; longitude: number; capacity: number };
export type Ride = { id: string; status: string; requested_at: string; released_at: string | null; ended_at: string | null; rider_id: string; bike_id: string; start_stand_id: string | null; end_stand_id: string | null; return_notes: string | null };
export type Issue = { id: string; issue_type: string; description: string; status: string; created_at: string; bike_id: string | null };

async function request<T>(path: string, options: RequestInit = {}, token?: string): Promise<T> {
  if (!env.key) throw new Error("Supabase publishable key is not configured. Copy the example environment file and check the key.");
  const response = await fetch(`${env.url}/${path}`, {
    ...options,
    headers: {
      apikey: env.key,
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
  const body = await response.text();
  const data = body ? JSON.parse(body) : null;
  if (!response.ok) throw new Error(data?.msg || data?.message || data?.hint || data?.details || data?.error_description || data?.error || `Request failed (${response.status})`);
  return data as T;
}

export async function signIn(email: string, password: string): Promise<Session> {
  return request<Session>("auth/v1/token?grant_type=password", { method: "POST", body: JSON.stringify({ email: email.trim().toLowerCase(), password }) });
}
export async function signUp(email: string, password: string, fullName: string): Promise<Session | { user: Session["user"]; message?: string }> {
  return request("auth/v1/signup", { method: "POST", body: JSON.stringify({ email: email.trim().toLowerCase(), password, data: { full_name: fullName.trim() } }) });
}
export async function signOut(token: string): Promise<void> {
  await request("auth/v1/logout", { method: "POST" }, token);
}
export async function getProfile(token: string, id: string): Promise<Profile | null> {
  const rows = await request<Profile[]>(`rest/v1/profiles?id=eq.${encodeURIComponent(id)}&select=*`, {}, token);
  return rows[0] || null;
}
export async function listBikes(token: string): Promise<Bike[]> {
  return request("rest/v1/bikes?select=id,short_code,status,notes,stand_id&order=short_code.asc", {}, token);
}
export async function listStands(token: string): Promise<Stand[]> {
  return request("rest/v1/stands?select=id,name,latitude,longitude,capacity&active=eq.true&order=name.asc", {}, token);
}
export async function listRides(token: string): Promise<Ride[]> {
  return request("rest/v1/rides?select=id,status,requested_at,released_at,ended_at,rider_id,bike_id,start_stand_id,end_stand_id,return_notes&order=requested_at.desc&limit=100", {}, token);
}
export async function listIssues(token: string): Promise<Issue[]> {
  return request("rest/v1/issue_reports?select=id,issue_type,description,status,created_at,bike_id&order=created_at.desc&limit=100", {}, token);
}
export async function requestRide(token: string, code: string): Promise<string> {
  return request("rest/v1/rpc/request_ride", { method: "POST", body: JSON.stringify({ p_bike_code: code }) }, token);
}
export async function cancelRide(token: string, id: string): Promise<void> {
  return request("rest/v1/rpc/cancel_ride_request", { method: "POST", body: JSON.stringify({ p_ride_id: id }) }, token);
}
export async function releaseRide(token: string, id: string): Promise<void> {
  return request("rest/v1/rpc/release_ride", { method: "POST", body: JSON.stringify({ p_ride_id: id }) }, token);
}
export async function completeRide(token: string, id: string, standId: string, notes: string): Promise<void> {
  return request("rest/v1/rpc/complete_ride", { method: "POST", body: JSON.stringify({ p_ride_id: id, p_return_stand_id: standId, p_notes: notes }) }, token);
}
export async function reportIssue(token: string, code: string, type: string, description: string): Promise<string> {
  return request("rest/v1/rpc/report_bike_issue", { method: "POST", body: JSON.stringify({ p_bike_code: code, p_issue_type: type, p_description: description }) }, token);
}
export async function inviteGuest(token: string, email: string): Promise<string> {
  return request("rest/v1/rpc/approve_guest", { method: "POST", body: JSON.stringify({ p_email: email.trim().toLowerCase() }) }, token);
}
export async function approveRider(token: string, id: string): Promise<void> {
  await request(`rest/v1/profiles?id=eq.${encodeURIComponent(id)}&status=eq.pending`, {
    method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ status: "approved" }),
  }, token);
}
export async function updateIssue(token: string, id: string, status: string): Promise<void> {
  await request(`rest/v1/issue_reports?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ status, ...(status === "resolved" ? { resolved_at: new Date().toISOString() } : {}) }),
  }, token);
}
export function isStaff(profile: Profile | null): boolean {
  return !!profile && ["attendant", "college_admin", "super_admin"].includes(profile.role) && profile.status === "approved";
}
