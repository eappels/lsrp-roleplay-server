# lsrp_taxi

First public civilian job built on top of `lsrp_jobs`.

## Features

- Registers the `taxi` job in the employment system.
- Taxi depot with a company vehicle bay and vehicle return point.
- Automatic dispatch-assigned fares with a pickup point, passenger ped, and drop-off destination.
- Fare rewards deposited into `lsrp_economy` on completion.

## Job Grades

- `driver`
- `senior_driver`

## Notes

- Passive payroll comes from `lsrp_jobs` while the employee is on duty.
- Active fare rewards come from this resource.

## Taxi Flow

1. Apply for `Downtown Cab` at the job center.
2. Go to the taxi depot.
3. Press `E` at the vehicle marker to clock in and collect a company taxi.
4. Once your company taxi is out, dispatch automatically assigns a fare.
5. Drive to the pickup point and collect the passenger from inside your company taxi.
6. Drive the passenger to their assigned destination and complete the fare from inside your company taxi.
7. After each drop-off, wait for dispatch to send the next fare.
8. Return the taxi to the depot return marker when finished.

## Depot Markers

- Vehicle marker: clock in and collect a taxi, or collect a replacement taxi while already on duty.
- Return marker: return your current company taxi.