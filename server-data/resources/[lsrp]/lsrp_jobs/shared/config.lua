Config = Config or {}

Config.Debug = false
Config.AdminAce = 'lsrp.jobs.admin'
Config.DefaultPayrollIntervalSeconds = 900
Config.MaxPayrollCatchUpIntervals = 2
Config.PayrollTickMs = 15000
Config.AllowPublicJobSwitching = true
Config.ClearDutyOnDisconnect = true

Config.StateBag = {
	jobId = 'lsrp_job',
	jobLabel = 'lsrp_job_label',
	gradeId = 'lsrp_job_grade',
	gradeLabel = 'lsrp_job_grade_label',
	duty = 'lsrp_job_duty',
	permissions = 'lsrp_job_permissions'
}