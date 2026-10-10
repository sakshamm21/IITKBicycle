import { z } from "zod";

import { LOCK_CODE_LENGTH } from "./constants";

export const userRoleSchema = z.enum(["rider", "attendant", "college_admin", "super_admin"]);
export type UserRole = z.infer<typeof userRoleSchema>;

export const profileStatusSchema = z.enum(["pending", "approved", "rejected", "suspended"]);
export type ProfileStatus = z.infer<typeof profileStatusSchema>;

export const bikeStatusSchema = z.enum(["available", "reserved", "in_ride", "maintenance", "missing", "retired"]);
export type BikeStatus = z.infer<typeof bikeStatusSchema>;

export const rideStatusSchema = z.enum(["requested", "active", "completed", "cancelled", "force_ended"]);
export type RideStatus = z.infer<typeof rideStatusSchema>;

export const issueTypeSchema = z.enum([
  "flat_tyre",
  "brakes",
  "chain",
  "lock",
  "missing",
  "other",
]);
export type IssueType = z.infer<typeof issueTypeSchema>;

export const issueStatusSchema = z.enum(["open", "in_progress", "resolved"]);
export type IssueStatus = z.infer<typeof issueStatusSchema>;

/** Bike label, for example K-042. */
export const bikeShortCodeSchema = z.string().regex(/^[A-Z]{1,3}-\d{3}$/);

export const lockCodeSchema = z.string().regex(new RegExp(`^\\d{${LOCK_CODE_LENGTH}}$`));
