//! Container Argument for Sub Commands, Options, and Values.
//!
//! A Command may contain any mix of those Arguments or none at all if it's to be used as a standalone Command.
//!
//! End User Example:
//!
//! ```
//! # Standalone Command
//! myapp help
//!
//! # Command w/ Options and Values
//! myapp -d "This Value belongs to the 'd' Option." --toggle "This is a standalone Value."
//! 
//! # Command w/ Sub Command
//! myapp --opt "Option for 'myapp' Command." subcmd --subcmd_opt "Option for 'subcmd' Sub Command."
//! ```

const std = @import("std");
const ascii = std.ascii;
const builtin = std.builtin;
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const meta = std.meta;
const sort = std.sort;
const ComptimeStringMap = std.ComptimeStringMap;
const StringHashMap = std.StringHashMap;

const toLower = ascii.toLower;
const toUpper = ascii.toUpper;

const Option = @import("Option.zig");
const Value = @import("Value.zig");
const utils = @import("utils.zig");


/// Config for custom Command Types. 
pub const Config = struct {
    /// Option Config for this Command Type.
    opt_config: Option.Config = .{},
    /// Value Config for this Command Type.
    val_config: Value.Config = .{},

    /// The Global Help Prefix for all instances of this Command Type.
    /// This can be overwritten per instance using the `help_prefix` field. 
    global_help_prefix: []const u8 = "",

    /// A custom Help function to override the default `help()` function globally for ALL Command instances of this custom Command Type.
    /// This function is 1st in precedence.
    ///
    /// Function parameters:
    /// 1. CommandT (This should be the `self` parameter. As such it needs to match the Command Type the function is being called on.)
    /// 2. Writer (This is the Writer that will written to.)
    /// 3. Allocator (This does not have to be used within in the function, but must be supported in case it's needed.)
    global_help_fn: ?*const fn(anytype, anytype, mem.Allocator)anyerror!void = null,
    /// A custom Usage function to override the default `usage()` function globally for ALL Command instances of this custom Command Type.
    /// This function is 1st in precedence.
    ///
    /// Function parameters:
    /// 1. CommandT (This should be the `self` parameter. As such it needs to match the Command Type the function is being called on.)
    /// 2. Writer (This is the Writer that will written to.)
    /// 3. Allocator (This does not have to be used within in the function, but must be supported in case it's needed.)
    global_usage_fn: ?*const fn(anytype, anytype, mem.Allocator)anyerror!void = null,

    /// Indent string used for Usage/Help formatting.
    /// Note, this will be used as the default across all Argument Types,
    /// but it can be overriden in the Option and Value Configs.
    indent_fmt: []const u8 = "    ",
    /// Group Title Format.
    /// Used for all Argument Type Groups.
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    /// 2. String (Indent)
    /// 3. String (Group Title)
    group_title_fmt: []const u8 = " {s}|{s}|\n",
    /// Group Separator string used for Help formatting.
    /// Used for all Argument Type Groups.
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    /// 2. String (Indent)
    group_sep_fmt: []const u8 = "{s}{s}\n",
    /// Help Format for the displayed Command
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    /// 2. String (Command Name)
    /// 3. String (Indent)
    /// 4. String (Command Description)
    help_header_fmt: []const u8 = 
        \\HELP:
        \\{s}COMMAND: {s}
        \\
        \\{s}DESCRIPTION: {s}
        \\
        \\
    ,
    /// Alias List Format for the displayed Command
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    /// 2. String (Aliases)
    /// Note, there will be curly-brackets `{}` surrounding the list due to how Zig handles printing `[]const []const u8`.
    cmd_alias_fmt: []const u8 = 
        \\{s}ALIAS(ES): {s}
        \\
        \\
    ,
    /// Usage Header Format
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    /// 2. String (Command)
    usage_header_fmt: []const u8 = 
        \\USAGE:
        \\{s}{s} 
    ,
    /// Sub Commands Help Title Format
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    subcmds_help_title_fmt: []const u8 = "{s}SUBCOMMANDS:\n",
    /// Options Help Title Format
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    opts_help_title_fmt: []const u8 = "{s}OPTIONS:\n",
    /// Values Help Title Format
    /// Must support the following format types in this order:
    /// 1. String (Indent)
    vals_help_title_fmt: []const u8 = "{s}VALUES:\n",
    /// Sub Commands Help Format.
    /// Must support the following format types in this order:
    /// 1. String (Command Name)
    /// 2. String (Command Description)
    subcmds_help_fmt: []const u8 = "{s}: {s}",
    /// Sub Commands Usage Format.
    /// Must support the following format types in this order:
    /// 1. String (Command Name)
    subcmds_usage_fmt: []const u8 = "{s}", 
    /// Sub Commands Alias List Format.
    /// Must support the following format types in this order:
    /// 1. String (Aliases)
    /// Note, there will be curly-brackets `{}` surrounding the list due to how Zig handles printing `[]const []const u8`.
    subcmd_alias_fmt: []const u8 = "[alias(es): {s}]",

    /// The Default Max Number of Arguments for Commands, Options, and Values individually.
    /// This is used for both `init()` and `from()` but can be overwritten for the latter.
    max_args: u8 = 25, 

    /// During parsing, mandate that a Sub Command be used with a Command if one is available.
    /// This will not include Usage/Help Commands.
    /// This can be overwritten on individual Commands using the `Command.Custom.sub_cmds_mandatory` field.
    global_sub_cmds_mandatory: bool = true,
    /// During parsing, mandate that all Values for a Command must be filled, otherwise error out.
    /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
    /// This can be overwritten on individual Commands using the `Command.Custom.vals_mandatory` field.
    global_vals_mandatory: bool = true,
    /// During parsing, mandate that Command instances of this Command Type, and their aliases, must be used in a case-sensitive manner.
    /// This will also affect Command Validation, but will NOT affect Tab-Completion.
    global_case_sensitive: bool = true,

    enable_verb_desc: bool = false,
};

/// Create a Command type with the Base (default) configuration.
pub fn Base() type { return Custom(.{}); }

/// Create a Custom Command type from the provided Config (`config`).
pub fn Custom(comptime config: Config) type {
    return struct {
        /// Value Config Setup
        const val_config = valConfig: {
            var setup_val_config = config.val_config;
            setup_val_config.indent_fmt = setup_val_config.indent_fmt orelse config.indent_fmt;
            break :valConfig setup_val_config;
        };
        /// Option Config Setup
        const opt_config = optConfig: {
            var setup_opt_config = config.opt_config;
            setup_opt_config.val_config = val_config;
            setup_opt_config.indent_fmt = setup_opt_config.indent_fmt orelse config.indent_fmt;
            break :optConfig setup_opt_config;
        };
        /// The Custom Option type to be used by this Custom Command type.
        pub const OptionT = Option.Custom(opt_config);
        /// The Custom Value type to be used by this Custom Command type.
        pub const ValueT = Value.Custom(val_config);

        /// Custom Help Function.
        /// Check (`Command.Config`) for details.
        pub const global_help_fn = config.global_help_fn;
        /// Custom Usage Function.
        /// Check (`Command.Config`) for details.
        pub const global_usage_fn = config.global_usage_fn;

        /// Group Title Format.
        /// Check (`Command.Config`) for details.
        pub const group_title_fmt = config.group_title_fmt;
        /// Group Separator Format.
        /// Check (`Command.Config`) for details.
        pub const group_sep_fmt = config.group_sep_fmt;
        /// Indent Format.
        /// Check (`Command.Config`) for details.
        pub const indent_fmt = config.indent_fmt;
        /// Help Header Format.
        /// Check (`Command.Config`) for details.
        pub const help_header_fmt = config.help_header_fmt;
        /// Alias List Header Format.
        /// Check (`Command.Config`) for details.
        pub const cmd_alias_fmt = config.cmd_alias_fmt;
        /// Usage Header Format.
        /// Check (`Command.Config`) for details.
        pub const usage_header_fmt = config.usage_header_fmt;
        /// Sub Commands Help Title Format.
        /// Check (`Command.Config`) for details.
        pub const subcmds_help_title_fmt = config.subcmds_help_title_fmt;
        /// Options Help Title Format.
        /// Check (`Command.Config`) for details.
        pub const opts_help_title_fmt = config.opts_help_title_fmt;
        /// Value Help Title Format.
        /// Check (`Command.Config`) for details.
        pub const vals_help_title_fmt = config.vals_help_title_fmt;
        /// Sub Commands Help Format.
        /// Check (`Command.Config`) for details.
        pub const subcmds_help_fmt = config.subcmds_help_fmt;
        /// Sub Commands Usage Format.
        /// Check (`Command.Config`) for details.
        pub const subcmds_usage_fmt = config.subcmds_usage_fmt;
        /// Sub Commands Alias List Format.
        /// Check (`Command.Config`) for details.
        pub const subcmd_alias_fmt = config.subcmd_alias_fmt;
        /// Global Help Prefix.
        /// Check (`Command.Config`) for details.
        pub const global_help_prefix = config.global_help_prefix;
        /// Max Args.
        /// Check (`Command.Config`) for details.
        pub const max_args = config.max_args;


        /// Flag denoting if this Command has been initialized to memory using `init()`.
        ///
        /// **Internal Use.**
        /// The Allocator for this Command.
        /// This is set using `init()`.
        ///
        /// **Internal Use.**
        _alloc: ?mem.Allocator = null,

        /// Command Groups.
        /// These groups are used for organizing sub-Commands in Help messages and other Generated docs.
        cmd_groups: ?[]const []const u8 = null,
        /// Command Group of this Command.
        /// This must line up with one of the Command Groups in the `cmd_groups` of the parent Command or it will be ignored.
        /// This can be Validated using `ValidateConfig.check_arg_groups`.
        cmd_group: ?[]const u8 = null,
        /// Option Groups.
        /// These groups are used for organizing Options in Help messages and other Generated docs.
        opt_groups: ?[]const []const u8 = null,
        /// Value Groups.
        /// These groups are used for organizing Values in Help messages and other Generated docs.
        val_groups: ?[]const []const u8 = null,

        /// The list of Sub Commands this Command can take.
        sub_cmds: ?[]const @This() = null,
        //sub_cmds: if (@inComptime()) ?[]const @This() else ?[]@This() = null,
        /// The Sub Command assigned to this Command during Parsing, if any.
        ///
        /// *This should be Read-Only for library users.*
        sub_cmd: ?*const @This() = null,
        //sub_cmd: ?*@This() = null,

        /// The list of Options this Command can take.
        opts: ?[]const OptionT = null,
        /// The list of Values this Command can take.
        vals: ?[]const ValueT = null,

        /// The Name of this Command for user identification and Usage/Help messages.
        name: []const u8,
        /// A list of Alias Names for this Command that can be used in place of `name`.
        alias_names: ?[]const []const u8 = null,
        /// The Prefix message used immediately before a Usage/Help message is displayed.
        help_prefix: []const u8 = global_help_prefix,
        /// The Description of this Command for Usage/Help messages.
        description: []const u8 = "",
        /// An optional Verbose Description for this Command.
        //verbose_description: ?[]const u8 = null,
        /// Hide thie Command from Usage/Help messages.
        hidden: bool = false,

        /// During parsing, mandate that a Sub Command be used with this Command if one is available.
        /// Note, this will not include Usage/Help Commands.
        sub_cmds_mandatory: bool = config.global_sub_cmds_mandatory,
        /// During parsing, mandate that Options in the provided Option Groups be used.
        /// This is a SUBSET of the `opt_groups`.
        mandatory_opt_groups: ?[]const []const u8 = null,
        /// During parsing, mandate that all Values for this Command must be filled, otherwise error out.
        /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
        vals_mandatory: bool = config.global_vals_mandatory,
        /// During parsing, mandate that THIS Command, and its aliases, must be used in a case-sensitive manner.
        /// This will NOT affect Command Validation nor Tab-Completion.
        case_sensitive: bool = config.global_case_sensitive,


        /// Sets the active Sub Command for this Command.
        pub fn setSubCmd(self: *const @This(), set_cmd: *const @This()) void {
            @constCast(self).*.sub_cmd = set_cmd;
        }
        //pub fn setSubCmd(self: *@This(), set_cmd: *@This()) void {
        //    self.sub_cmd = set_cmd;
        //}
        /// Gets a reference to the Sub Command of this Command that matches the provided Name (`cmd_name`).
        pub fn getSubCmd(self: *const @This(), cmd_name: []const u8) ?*const @This() {
            if (self.sub_cmds == null) return null;
            for (self.sub_cmds.?[0..]) |*cmd| if (mem.eql(u8, cmd.name, cmd_name)) return cmd;
            return null;
        }
        /// Check if the active Sub Command of this Command has the provided Name (`cmd_name`).
        /// This is useful for analyzing Commands that DO NOT have Sub Commands that need to be subsequently analyzed.
        pub fn checkSubCmd(self: *const @This(), cmd_name: []const u8) bool {
            return if (self.sub_cmd) |cmd| mem.eql(u8, cmd.name, cmd_name) else false;
        }
        /// Returns the active Sub Command of this Command if it matches the provided Name (`cmd_name`). 
        /// This is useful for analyzing Commands that DO have Sub Commands that need to be subsequently analyzed.
        pub fn matchSubCmd(self: *const @This(), cmd_name: []const u8) ?*const @This() {
            return if (self.checkSubCmd(cmd_name)) self.sub_cmd.? else null;
        }

        /// Config for Getting Options and Values.
        pub const GetConfig = struct{
            /// An optional Argument Group to filter the returned Options or Values.
            arg_group: ?[]const u8 = null,
        };

        /// Gets a StringHashMap of this Command's Options using its initialization Allocator.
        pub fn getOpts(self: *const @This(), get_config: GetConfig) !StringHashMap(OptionT) {
            const alloc = self._alloc orelse return error.CommandNotInitialized;
            return self.getOptsAlloc(alloc, get_config);
        }
        /// Gets a StringHashMap of this Command's Options using the provided Allocator (`alloc`).
        pub fn getOptsAlloc(self: *const @This(), alloc: mem.Allocator, get_config: GetConfig) !StringHashMap(OptionT) {
            if (self.opts == null) return error.NoOptionsInCommand;
            var map = StringHashMap(OptionT).init(alloc);
            for (self.opts.?) |opt| { 
                checkGroup: {
                    const conf_group = get_config.arg_group orelse break :checkGroup;
                    const opt_group = opt.opt_group orelse continue;
                    if (!mem.eql(u8, conf_group, opt_group)) continue;
                }
                try map.put(opt.name, opt); 
            }
            return map;
        }
        /// Config for Checking or Matching multiple Options from this Command.
        pub const OptionsCheckConfig = struct{
            /// The type of Boolean Logic to be used when checking or matching Options.
            logic: CheckLogic = .OR,
            /// The maximum number of Options allowed for XOR Logic.
            /// This technically breaks from actual XOR Logic, but allows a specific number of Options to be checked or matched.
            xor_max: u8 = 1,
            /// An optional Option Group to filter Checks/Matches.
            opt_group: ?[]const u8 = null,

            /// Boolean Logic types for checking/matching Options.
            pub const CheckLogic = enum{
                /// All Options from the provided list must be set.
                AND,
                /// At least one Option from the provided list must be set.
                OR,
                /// Exactly `xor_mx` number of Options from the provided list must be set.
                XOR,
            };
        };
        /// Check if certain Options (`opt_names`) of this Command have been set using the provided OptionsCheckConfig (`check_config`).
        pub fn checkOpts(self: *const @This(), opt_names: []const []const u8, check_config: OptionsCheckConfig) bool {
            const cmd_opts = self.opts orelse return false;
            var logic_flag = false;
            var opts_count: u8 = 0;
            for (cmd_opts) |opt| {
                checkGroup: {
                    const conf_group = check_config.opt_group orelse break :checkGroup;
                    const opt_group = opt.opt_group orelse continue;
                    if (!mem.eql(u8, conf_group, opt_group)) continue;
                }
                _ = utils.indexOfEql([]const u8, opt_names, opt.name) orelse continue;
                if (!opt.val.isSet()) continue;
                opts_count += 1;
                switch (check_config.logic) {
                    .AND => {
                        if (opts_count == opt_names.len) {
                            logic_flag = true;
                            break;   
                        }    
                    },
                    .OR => logic_flag = true,
                    .XOR => {
                        if (opts_count > check_config.xor_max) {
                            logic_flag = false;
                            break;
                        }
                        logic_flag = true;
                    },
                }
            }
            return logic_flag;
        }
        /// Returns a slice of Options `[]OptionT` Matching the given Options list (`opt_names`) and rules provided in the OptionCheckConfig (`check_config`).
        /// This implementation uses this Command's initialization Allocator to allocate the OptionT slice.
        pub fn matchOpts(self: *const @This(), opt_names: []const []const u8, check_config: OptionsCheckConfig) ![]OptionT {
            const alloc = self._alloc orelse return error.CommandNotInitialized;
            return self.matchOptsAlloc(opt_names, alloc, check_config);
        }
        /// Returns a slice of Options `[]OptionT` Matching the given Options list (`opt_names`) and rules provided in the OptionCheckConfig (`check_config`).
        /// This implementation uses the provided Allocator (`alloc`) to allocate the OptionT slice.
        pub fn matchOptsAlloc(self: *const @This(), opt_names: []const []const u8, alloc: mem.Allocator, check_config: OptionsCheckConfig) ![]OptionT {
            const cmd_opts = self.opts orelse return error.NoOptionsInCommand;
            var opts_list = std.ArrayList(OptionT).init(alloc);
            errdefer opts_list.deinit();
            var logic_flag = false;
            for (cmd_opts) |opt| {
                checkGroup: {
                    const conf_group = check_config.opt_group orelse break :checkGroup;
                    const opt_group = opt.opt_group orelse continue;
                    if (!mem.eql(u8, conf_group, opt_group)) continue;
                }
                _ = utils.indexOfEql([]const u8, opt_names, opt.name) orelse continue;
                if (!opt.val.isSet()) continue;
                try opts_list.append(opt);
                switch (check_config.logic) {
                    .AND => {
                        if (opts_list.items.len == opt_names.len) {
                            logic_flag = true;
                            break;   
                        }    
                    },
                    .OR => logic_flag = true,
                    .XOR => {
                        if (opts_list.items.len > check_config.xor_max) {
                            logic_flag = false;
                            break;
                        }
                        logic_flag = true;
                    },
                }
            }
            if (!logic_flag) {
                return switch (check_config.logic) {
                    .AND => error.MatchOptionLogicFailAND,
                    .OR => error.MatchOptionLogicFailOR,
                    .XOR => error.MatchOptionLogicFailXOR,
                };
            }
            return try opts_list.toOwnedSlice();
        }

        /// Gets a StringHashMap of this Command's Values using its initialization Allocator.
        pub fn getVals(self: *const @This(), get_config: GetConfig) !StringHashMap(ValueT) {
            const alloc = self._alloc orelse return error.CommandNotInitialized;
            return self.getValsAlloc(alloc, get_config);
        }
        /// Gets a StringHashMap of this Command's Values using the provided Allocator (`alloc`).
        pub fn getValsAlloc(self: *const @This(), alloc: mem.Allocator, get_config: GetConfig) !StringHashMap(ValueT) {
            if (self.vals == null) return error.NoValuesInCommand;
            var map = StringHashMap(ValueT).init(alloc);
            for (self.vals.?) |val| { 
                checkGroup: {
                    const conf_group = get_config.arg_group orelse break :checkGroup;
                    const val_group = val.valGroup() orelse continue;
                    if (!mem.eql(u8, conf_group, val_group)) continue;
                }
                try map.put(val.name(), val); 
            }
            return map;
        }

        /// Creates the Help message for this Command and writes it to the provided Writer (`writer`).
        pub fn help(self: *const @This(), writer: anytype) !void {
            if (global_help_fn) |helpFn| return helpFn(self, writer, self._alloc orelse return error.CommandNotInitialized);

            const alloc = self._alloc orelse return error.CommandNotInitialized;
            
            try writer.print("{s}\n", .{ self.help_prefix });
            try self.usage(writer);
            try writer.print(help_header_fmt, .{ 
                indent_fmt, self.name, 
                indent_fmt, self.description 
            });

            if (self.alias_names) |aliases| try writer.print(cmd_alias_fmt, .{ indent_fmt, aliases });

            if (self.sub_cmds) |sub_cmds| {
                try writer.print(subcmds_help_title_fmt, .{ indent_fmt });
                var cmd_list = std.StringArrayHashMap(@This()).init(alloc);
                defer cmd_list.deinit();
                for (sub_cmds) |cmd| try cmd_list.put(cmd.name, cmd);
                var remove_list = std.ArrayList([]const u8).init(alloc);
                defer remove_list.deinit();
                if (self.cmd_groups) |groups| {
                    var need_other_title = false;
                    for (groups) |group| {
                        var need_title = true;
                        var cmd_iter = cmd_list.iterator();
                        cmdGroup: while (cmd_iter.next()) |cmd_entry| {
                            const cmd = cmd_entry.value_ptr;
                            if (cmd.hidden) {
                                try remove_list.append(cmd.name);
                                continue;
                            }
                            if (mem.eql(u8, cmd.cmd_group orelse continue :cmdGroup, group)) {
                                if (need_title) {
                                    try writer.print(group_title_fmt, .{ indent_fmt, group });
                                    need_title = false;
                                    need_other_title = true;
                                }
                                try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                                try writer.print(subcmds_help_fmt, .{ cmd.name, cmd.description });
                                if (cmd.alias_names) |aliases| {
                                    try writer.print("\n{s}{s}{s}", .{ indent_fmt, indent_fmt, indent_fmt });
                                    try writer.print(subcmd_alias_fmt, .{ aliases });
                                }
                                try writer.print("\n", .{});
                                try remove_list.append(cmd.name);
                            }
                        }
                        if (!need_title) try writer.print(group_sep_fmt, .{ indent_fmt, indent_fmt });
                    }
                    if (need_other_title and remove_list.items.len < cmd_list.count()) try writer.print(group_title_fmt, .{ indent_fmt, "OTHER" });
                }
                for (remove_list.items) |rem_name| _ = cmd_list.orderedRemove(rem_name);

                var cmd_iter = cmd_list.iterator();
                while (cmd_iter.next()) |cmd_entry| {
                    const cmd = cmd_entry.value_ptr;
                    if (cmd.hidden) continue;
                    try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                    try writer.print(subcmds_help_fmt, .{ cmd.name, cmd.description });
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});

            if (self.opts) |opts| {
                try writer.print(opts_help_title_fmt, .{ indent_fmt });
                var opt_list = std.StringArrayHashMap(OptionT).init(alloc);
                defer opt_list.deinit();
                for (opts) |opt| try opt_list.put(opt.name, opt);
                var remove_list = std.ArrayList([]const u8).init(alloc);
                defer remove_list.deinit();
                if (self.opt_groups) |groups| {
                    var need_other_title = false;
                    for (groups) |group| {
                        var need_title = true;
                        var opt_iter = opt_list.iterator();
                        optGroup: while (opt_iter.next()) |opt_entry| {
                            const opt = opt_entry.value_ptr;
                            if (opt.hidden) {
                                try remove_list.append(opt.name);
                                continue;
                            }
                            if (mem.eql(u8, opt.opt_group orelse continue :optGroup, group)) {
                                if (need_title) {
                                    try writer.print(group_title_fmt, .{ indent_fmt, group });
                                    need_title = false;
                                    need_other_title = true;
                                }
                                try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                                try opt.help(writer);
                                try writer.print("\n", .{});
                                try remove_list.append(opt.name);
                            }
                        }
                        if (!need_title) try writer.print(group_sep_fmt, .{ indent_fmt, indent_fmt });
                    }
                    if (need_other_title and remove_list.items.len < opt_list.count()) try writer.print(group_title_fmt, .{ indent_fmt, "OTHER" });
                }
                for (remove_list.items) |rem_name| _ = opt_list.orderedRemove(rem_name);

                var opt_iter = opt_list.iterator();
                while (opt_iter.next()) |opt_entry| {
                    const opt = opt_entry.value_ptr;
                    if (opt.hidden) continue;
                    try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                    try opt.help(writer);
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});

            if (self.vals) |vals| {
                try writer.print(vals_help_title_fmt, .{ indent_fmt });
                var val_list = std.StringArrayHashMap(ValueT).init(alloc);
                defer val_list.deinit();
                for (vals) |val| try val_list.put(val.name(), val);
                var remove_list = std.ArrayList([]const u8).init(alloc);
                defer remove_list.deinit();
                if (self.val_groups) |groups| {
                    var need_other_title = false;
                    for (groups) |group| {
                        var need_title = true;
                        var val_iter = val_list.iterator();
                        valGroup: while (val_iter.next()) |val_entry| {
                            const val = val_entry.value_ptr;
                            if (mem.eql(u8, val.valGroup() orelse continue :valGroup, group)) {
                                if (need_title) {
                                    try writer.print(group_title_fmt, .{ indent_fmt, group });
                                    need_title = false;
                                    need_other_title = true;
                                }
                                try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                                try val.help(writer);
                                try writer.print("\n", .{});
                                try remove_list.append(val.name());
                            }
                        }
                        if (!need_title) try writer.print(group_sep_fmt, .{ indent_fmt, indent_fmt });
                    }
                    if (need_other_title and remove_list.items.len < val_list.count()) try writer.print(group_title_fmt, .{ indent_fmt, "OTHER" });
                }
                for (remove_list.items) |rem_name| _ = val_list.orderedRemove(rem_name);

                var val_iter = val_list.iterator();
                while (val_iter.next()) |val_entry| {
                    const val = val_entry.value_ptr;
                    try writer.print("{s}{s}", .{ indent_fmt, indent_fmt });
                    try val.help(writer);
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});
        }

        /// Creates the Usage message for this Command and writes it to the provided Writer (`writer`).
        pub fn usage(self: *const @This(), writer: anytype) !void {
            if (global_usage_fn) |usageFn| return usageFn(self, writer, self._alloc orelse return error.CommandNotInitialized);

            try writer.print(usage_header_fmt, .{ indent_fmt, self.name });
            if (self.opts) |opts| {
                var post_sep: []const u8 = " | ";
                var hidden_count: u8 = 0;
                for (opts, 0..) |opt, idx| {
                    if (opt.hidden) {
                        hidden_count += 1;
                        continue;
                    }
                    try opt.usage(writer);
                    if (idx == opts.len - 1) post_sep = "";
                    try writer.print("{s}", .{ post_sep });
                }
                if (hidden_count < opts.len) try writer.print("\n{s}{s} ", .{ indent_fmt, self.name });
            }
            if (self.vals) |vals| {
                var post_sep: []const u8 = " | ";
                for (vals, 0..) |val, idx| {
                    try val.usage(writer);
                    if (idx == vals.len - 1) post_sep = "";
                    try writer.print("{s}", .{ post_sep });
                }
                try writer.print("\n{s}{s} ", .{ indent_fmt, self.name });
            }
            if (self.sub_cmds) |cmds| {
                var post_sep: []const u8 = " | ";
                for (cmds, 0..) |cmd, idx| {
                    if (cmd.hidden) continue;
                    try writer.print(subcmds_usage_fmt, .{ cmd.name });
                    if (idx == cmds.len - 1) post_sep = "";
                    try writer.print("{s}", .{ post_sep });
                }
            } 

            try writer.print("\n\n", .{});
        }

        /// Check if Usage or Help have been set and call their respective methods.
        /// Output will be written to the provided Writer (`writer`).
        pub fn checkUsageHelp(self: *const @This(), writer: anytype) !bool {
            if (self.checkFlag("usage")) {
                try self.usage(writer);
                return true;
            }
            if (self.checkFlag("help")) {
                try self.help(writer);
                return true;
            }
            return false;
        }

        /// Check if a Flag (`flag_name`) has been set on this Command as a Command, Option, or Value.
        /// This is particularly useful for checking if Help or Usage has been called.
        pub fn checkFlag(self: *const @This(), flag_name: []const u8) bool {
            return (
                (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, flag_name)) or
                checkOpt: {
                    if (self.opts != null) {
                        for (self.opts.?) |opt| {
                            if (mem.eql(u8, opt.name, flag_name) and 
                                mem.eql(u8, opt.val.childType(), "bool") and 
                                opt.val.getAs(bool) catch false)
                                    break :checkOpt true;
                        }
                    }
                    break :checkOpt false;
                } or
                checkVal: {
                    if (self.vals != null) {
                        for (self.vals.?) |val| {
                            if (mem.eql(u8, val.name(), flag_name) and
                                mem.eql(u8, val.childType(), "bool") and
                                val.getAs(bool) catch false)
                                    break :checkVal true;
                        }
                    }
                    break :checkVal false;
                }
            );
        }

        /// Config for creating Commands from Structs using `from()`.
        pub const FromConfig = struct {
            /// Ignore incompatible Types.
            ignore_incompatible: bool = true,
            /// Ignore prefix.
            /// Any Field that matches this prefix will not be converted in to an Argument Type.
            /// Setting this to `null` will disable prefix checks.
            ignore_prefix: ?[]const u8 = "_",
            /// Ignore the first field or parameter.
            /// This is particularly useful when converting a Function that has a `self` parameter.
            ignore_first: bool = false,
            /// Convert underscores '_' to dashes '-' in field names.
            /// Be sure to set the counterpart to this flag in the `ToConfig` if this Command will be converted back to a Struct or Union.
            convert_syntax: bool = true,
            /// Attempt to create Short Options.
            /// This will attempt to make a short option name from the first letter of the field name in lowercase then uppercase, 
            /// sequentially working through each next letter if the previous one has already been used. 
            /// (Note, user must deconflict for 'u' and 'h' if using auto-generated Usage/Help Options.)
            attempt_short_opts: bool = true,
            /// Convert Fields with default values to Options instead of Values.
            /// There's a corresponding field in the `ToConfig`.
            default_val_opts: bool = false,

            /// A Name for the Command.
            /// A null value will default to the type name of the Struct.
            cmd_name: ?[]const u8 = null,
            /// A list of Alias Names for this Command.
            cmd_alias_names: ?[]const []const u8 = null,
            /// A Description for the Command.
            cmd_description: []const u8 = "",
            /// A Help Prefix for the Command.
            cmd_help_prefix: []const u8 = global_help_prefix,
            /// Command Groups for this Command
            cmd_groups: ?[]const []const u8 = null,
            /// Command Group for this Command.
            cmd_group: ?[]const u8 = null,
            /// Hide this Command.
            cmd_hidden: bool = false,

            /// Descriptions of the Command's Arguments (Sub Commands, Options, and Values).
            /// These Descriptions will be used across this Command and all of its Sub Commands.
            ///
            /// Format: `.{ "argument_name", "Description of the Argument." }`
            sub_descriptions: []const struct { []const u8, []const u8 } = &.{ .{ "__nosubdescriptionsprovided__", "" } },
            /// During parsing, mandate that a Sub Command be used with a Command if one is available.
            /// This will not include Usage/Help Commands.
            sub_cmds_mandatory: bool = config.global_sub_cmds_mandatory,
            /// During parsing, mandate that all Values for a Command must be filled, otherwise error out.
            /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
            vals_mandatory: bool = config.global_vals_mandatory,
            /// During parsing, mandate that THIS Command, and its aliases, must be used in a case-sensitive manner.
            /// This will NOT affect Command Validation nor Tab-Completion.
            case_sensitive: bool = config.global_case_sensitive,

            /// Max number of Sub Commands.
            max_cmds: u8 = max_args,
            /// Max number of Options.
            max_opts: u8 = max_args,
            /// Max number of Values.
            max_vals: u8 = max_args,
        };
        
        /// Create a Command from the provided Type (`FromT`).
        /// The provided Type must be a Comptime-known Function, Struct, or Union.
        pub fn from(comptime FromT: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(FromT);
            return switch (from_info) {
                .Fn => fromFn(FromT, from_config),
                .Struct, .Union => fromStructOrUnion(FromT, from_config),
                else => @compileError("The provided type '" ++ @typeName(FromT) ++ "' must be a Function, Struct, or Union."),
            };
        }

        /// Create a Command from the provided Struct (`FromStruct`).
        /// The provided Struct must be Comptime-known.
        ///
        /// Field Types are converted as follows:
        /// - Functions, Structs, Unions = Commands
        /// - Valid Values = Single-Values (Valid Values can be found under `Value.zig/Generic`.)
        /// - Valid Optionals = Single-Options (Valid Optionals are nullable versions of Valid Values.)
        /// - Arrays of Valid Values = Multi-Values
        /// - Arrays of Valid Optionals = Multi-Options 
        pub fn fromStructOrUnion(comptime FromT: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(FromT);
            if (from_info != .Struct and from_info != .Union) @compileError("Provided Type is not a Struct or Union.");

            var from_cmds_buf: [from_config.max_cmds]@This() = undefined;
            const from_cmds = from_cmds_buf[0..];
            var cmds_idx: u8 = 0;
            var from_opts_buf: [from_config.max_opts]OptionT = undefined;
            const from_opts = from_opts_buf[0..];
            var opts_idx: u8 = 0;
            var short_names_buf: [from_config.max_opts]u8 = undefined;
            const short_names = short_names_buf[0..];
            var short_idx: u8 = 0;
            var from_vals_buf: [from_config.max_vals]ValueT = undefined;
            const from_vals = from_vals_buf[0..];
            var vals_idx: u8 = 0;

            // TODO: Make this a nullable field and just use null conditional syntax for adding descriptions below.
            const arg_descriptions = ComptimeStringMap([]const u8, from_config.sub_descriptions);

            const fields = meta.fields(FromT);
            const start_idx = if (from_config.ignore_first) 1 else 0;
            inline for (fields[start_idx..]) |field| {
                if (from_config.ignore_prefix) |prefix| {
                    if (field.name.len > prefix.len and mem.eql(u8, field.name[0..prefix.len], prefix)) continue;
                }
                var arg_name_buf: [field.name.len]u8 = field.name[0..].*;
                const arg_name = if (!from_config.convert_syntax) field.name else argName: {
                    _ = mem.replace(u8, field.name[1..], "_", "-", arg_name_buf[1..]);
                    break :argName arg_name_buf[0..];
                };
                const arg_description = arg_descriptions.get(field.name);
                // Handle Argument Types.
                switch (field.type) {
                    @This() => {
                        if (field.default_value != null) {
                            from_cmds[cmds_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            cmds_idx += 1;
                            continue;
                        }
                    },
                    OptionT => {
                        if (field.default_value != null) {
                            from_opts[opts_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            opts_idx += 1;
                            continue;
                        }
                    },
                    ValueT => {
                        if (field.default_value != null) {
                            from_vals[vals_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            vals_idx += 1;
                            continue;
                        }
                    },
                    inline else => {},
                }

                const field_info = @typeInfo(field.type);
                // Handle non-Argument Types.
                switch (field_info) {
                    // Commands
                    .Fn, .Struct => {
                        const sub_config = comptime subConfig: {
                            var new_config = from_config;
                            new_config.cmd_name = arg_name;
                            new_config.cmd_description = arg_description orelse "The '" ++ arg_name ++ "' Command.";
                            break :subConfig new_config;
                        };
                        from_cmds[cmds_idx] = from(field.type, sub_config);
                        cmds_idx += 1;
                    },
                    // Options
                    // TODO - Handle Command types passed as Optionals?
                    .Optional => {
                        from_opts[opts_idx] = (OptionT.from(field, .{ 
                            .name = arg_name,
                            .short_name = if (from_config.attempt_short_opts) optShortName(arg_name, short_names, &short_idx) else null, 
                            .long_name = arg_name,
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .opt_description = arg_description,
                        }) orelse continue);
                        opts_idx += 1;
                    },
                    // Values
                    .Bool, .Int, .Float, .Pointer, .Enum => {
                        if (from_config.default_val_opts and field.default_value != null) {
                            from_opts[opts_idx] = (OptionT.from(field, .{ 
                                .name = arg_name,
                                .short_name = if (from_config.attempt_short_opts) optShortName(arg_name, short_names, &short_idx) else null, 
                                .long_name = arg_name,
                                .ignore_incompatible = from_config.ignore_incompatible,
                                .opt_description = arg_description,
                            }) orelse continue);
                            opts_idx += 1;
                            continue;
                        }
                        from_vals[vals_idx] = (ValueT.from(field, .{
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .val_name = arg_name,
                            .val_description = arg_description,
                        }) orelse continue);
                        vals_idx += 1;
                    },
                    // Multi
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            // Options
                            .Optional => {
                                from_opts[opts_idx] = OptionT.from(field, .{
                                    .name = arg_name,
                                    .short_name = if (from_config.attempt_short_opts) optShortName(arg_name, short_names, &short_idx) else null, 
                                    .long_name = arg_name,
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .opt_description = arg_description
                                }) orelse continue;
                                opts_idx += 1;
                            },
                            // Values
                            .Bool, .Int, .Float, .Pointer, .Enum => {
                                from_vals[vals_idx] = ValueT.from(field, .{
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .val_name = arg_name,
                                    .val_description = arg_description
                                }) orelse continue;
                                vals_idx += 1;
                            },
                            else => if (!from_config.ignore_incompatible) @compileError("The field '" ++ field.name ++ "' of type 'Array' is incompatible. Arrays must contain one of the following types: Bool, Int, Float, Pointer (const u8), or their Optional counterparts."),
                        }
                    },
                    // Incompatible
                    else => if (!from_config.ignore_incompatible) @compileError("The field '" ++ field.name ++ "' of type '" ++ @typeName(field.type) ++ "' is incompatible as it cannot be converted to a Command, Option, or Value."),
                }
            }

            var cmd_name_buf: [@typeName(FromT).len]u8 = undefined;
            const cmd_name = if (from_config.cmd_name) |c_name| c_name else cmdName: {
                if (!from_config.convert_syntax) break :cmdName @typeName(FromT) else {
                    _ = mem.replace(u8, @typeName(FromT), "_", "-", cmd_name_buf[0..]);
                    break :cmdName cmd_name_buf[0..];
                }
            };
            return @This(){
                .name = cmd_name,
                .alias_names = from_config.cmd_alias_names,
                .description = from_config.cmd_description,
                .hidden = from_config.cmd_hidden,
                .help_prefix = from_config.cmd_help_prefix,
                .cmd_groups = from_config.cmd_groups,
                .cmd_group = from_config.cmd_group,
                .sub_cmds = if (cmds_idx > 0) from_cmds[0..cmds_idx] else null,
                .opts = if (opts_idx > 0) from_opts[0..opts_idx] else null,
                .vals = if (vals_idx > 0) from_vals[0..vals_idx] else null,
                .sub_cmds_mandatory = from_config.sub_cmds_mandatory,
                .vals_mandatory = from_config.vals_mandatory,
                .case_sensitive = from_config.case_sensitive,
            };
        }
        /// Create a deconflicted Option short name from the provided `arg_name` and existing `short_names`.
        fn optShortName(arg_name: []const u8, short_names: []u8, short_idx: *u8) ?u8 {
            return shortName: {
                for (arg_name) |char| {
                    const ul_chars: [2]u8 = .{ toLower(char), toUpper(char) };
                    for (ul_chars) |ul| {
                        if (short_idx.* > 0 and utils.indexOfEql(u8, short_names[0..short_idx.*], ul) != null) continue;
                        short_names[short_idx.*] = ul;
                        short_idx.* += 1;
                        break :shortName ul;
                    }
                }
                break :shortName null;
            };
        }

        /// Create a Command from the provided Function (`from_fn`).
        /// The provided Function must be Comptime-known.
        ///
        /// Types are converted as follows:
        /// - Functions, Structs, Unions = Commands
        /// - Valid Single-Parameters = Single-Values (Valid Values can be found under `Value.zig/Generic`.)
        /// - Valid Array/Slice-Parameters = Multi-Values
        /// - Note: Options can not be generated from Functions due to the lack of parameter names in `std.builtin.Type.Fn.Param`.
        pub fn fromFn(comptime FromFn: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(FromFn);
            if (from_info != .Fn) @compileError("Provided Type is not a Function.");

            var from_cmds_buf: [from_config.max_cmds]@This() = undefined;
            const from_cmds = from_cmds_buf[0..];
            var cmds_idx: u8 = 0;
            var from_vals_buf: [from_config.max_vals]ValueT = undefined;
            const from_vals = from_vals_buf[0..];
            var vals_idx: u8 = 0;

            //const arg_descriptions = ComptimeStringMap([]const u8, from_config.sub_descriptions);

            const params = from_info.Fn.params;
            const start_idx = if (from_config.ignore_first) 1 else 0;
            inline for (params[start_idx..]) |param| {
                const arg_description = "No description. (Descriptions cannot currently be generated from Function Parameters.)";//arg_descriptions.get(param.name);
                // Handle Argument Types.
                switch (@typeInfo(param.type.?)) {
                    // Commands
                    .Fn, .Struct, .Union => {
                        const sub_config = comptime subConfig: {
                            var new_config = from_config;
                            new_config.cmd_name = "cmd-" ++ &.{ cmds_idx + 48 };
                            new_config.cmd_description = arg_description orelse "The '" ++ new_config.cmd_name ++ "' Command.";
                            break :subConfig new_config;
                        };
                        from_cmds[cmds_idx] = from(param.type, sub_config);
                        cmds_idx += 1;
                    },
                    // Values
                    .Bool, .Int, .Float, .Optional, .Pointer, .Enum => {
                        from_vals[vals_idx] = (ValueT.from(param, .{
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .val_name = "val-" ++ .{ '0', (vals_idx + 48), },
                            .val_description = arg_description,
                        }) orelse continue);
                        vals_idx += 1;
                    },
                    // Multi
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            // Values
                            .Bool, .Int, .Float, .Optional, .Pointer, .Enum => {
                                from_vals[vals_idx] = ValueT.from(param, .{
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .val_description = arg_description
                                }) orelse continue;
                                vals_idx += 1;
                            },
                            else => if (!from_config.ignore_incompatible) @compileError("The parameter of type 'Array' is incompatible. Arrays must contain one of the following types: Bool, Int, Float, Pointer (const u8), or their Optional counterparts."),
                        }
                    },
                    // Incompatible
                    else => if (!from_config.ignore_incompatible) @compileError("The parameter of type '" ++ @typeName(param.type) ++ "' is incompatible as it cannot be converted to a Command or Value."),
                }
            }

            return @This(){
                .name = if (from_config.cmd_name) |c_name| c_name else @typeName(FromFn),
                .alias_names = from_config.cmd_alias_names,
                .description = from_config.cmd_description,
                .hidden = from_config.cmd_hidden,
                .cmd_groups = from_config.cmd_groups,
                .cmd_group = from_config.cmd_group,
                .help_prefix = from_config.cmd_help_prefix,
                .sub_cmds = if (cmds_idx > 0) from_cmds[0..cmds_idx] else null,
                .vals = if (vals_idx > 0) from_vals[0..vals_idx] else null,
                .sub_cmds_mandatory = from_config.sub_cmds_mandatory,
                .vals_mandatory = true,
                .case_sensitive = from_config.case_sensitive,
            };
        }

        /// Config for creating Structs from Commands using `to()`.
        pub const ToConfig = struct {
            /// Allow Unset Options and Values to be included.
            /// When this is active, an attempt will be made to use the Struct's default value (if available) in the event of an Unset Option/Value.
            allow_unset: bool = true,
            /// Ignore Incompatible types. Incompatible types are those that fall outside of the conversion rules listed under `from()`.
            /// When this is active, an attempt will be made to use the Struct's default value (if available) in the event of an Incompatible type.
            /// This will also allow Values to be set to sane defaults for Integers and Floats (0) as well as Strings ("").
            allow_incompatible: bool = true,
            /// Convert dashes '-' to underscores '_' in field names.
            /// Be sure to set the counterpart to this flag in the `FromConfig` if this Command will be converted from a Struct or Union.
            convert_syntax: bool = true,
            /// Allow Fields with a default value to come from Options or Values.
            /// There's a corresponding field in the `FromConfig`.
            default_val_opts: bool = true,
        };

        /// Convert this Command to an instance of the provided Struct or Union Type (`toT`).
        /// This is the inverse of `from()`.
        ///
        /// Types are converted as follows:
        /// - Commmands: Structs or Unions by recursively calling `to()`.
        /// - Single-Options: Optional versions of Values.
        /// - Single-Values: Booleans, Integers (Signed/Unsigned), and Pointers (`[]const u8`) only)
        /// - Multi-Options/Values: Arrays of the corresponding Optionals or Values.
        // TODO: Catch more error cases for incompatible types (i.e. Pointer not (`[]const u8`).
        pub fn to(self: *const @This(), comptime ToT: type, to_config: ToConfig) !ToT {
            const alloc = self._alloc orelse return error.CommandNotInitialized;
            const type_info = @typeInfo(ToT);
            if (type_info == .Union) { 
                const vals_idx = if (self.vals) |vals| valsIdx: {
                    var idx: u8 = 0;
                    for (vals) |val| { if (val.isSet()) idx += 1; }
                    break :valsIdx idx;
                } else 0;
                const opts_idx = if (self.opts) |opts| optsIdx: {
                    var idx: u8 = 0;
                    for (opts) |opt| { 
                        if (
                            opt.val.isSet() and
                            !mem.eql(u8, opt.name, "usage") and
                            !mem.eql(u8, opt.name, "help")
                        ) idx += 1; 
                    }
                    break :optsIdx idx;
                } else 0;
                const total_idx = vals_idx + opts_idx;
                if (total_idx > 1) { 
                    log.err("Commands from Unions can only hold 1 Value or Option, but '{d}' were given.", .{ total_idx });
                    return error.ExpectedOnlyOneValOrOpt;
                }
            }
            const vals = getVals: {
                var valsList = std.ArrayList(ValueT).init(alloc);
                try valsList.appendSlice(self.vals orelse &.{});
                if (to_config.default_val_opts) optVals: {
                    for (self.opts orelse break :optVals) |opt| try valsList.append(opt.val);
                }
                break :getVals try valsList.toOwnedSlice();
            };
            defer alloc.free(vals);
            var out: ToT = undefined;
            const fields = meta.fields(ToT);
            inline for (fields) |field| {
                if (field.type == @This() or field.type == OptionT or field.type == ValueT) continue;
                var arg_name_buf: [field.name.len]u8 = field.name[0..].*;
                const arg_name = if (!to_config.convert_syntax) field.name else argName: {
                    _ = mem.replace(u8, field.name[1..], "_", "-", arg_name_buf[1..]);
                    break :argName arg_name_buf[0..];
                };
                const field_info = @typeInfo(field.type);
                switch (field_info) {
                    .Struct => {
                        @field(out, field.name) = 
                            if (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, arg_name))
                                try self.sub_cmd.?.to(field.type, to_config)
                            else if (to_config.allow_unset) field.type{}
                            else return error.ValueNotSet;
                    },
                    .Union => if (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, arg_name)) {
                        return @unionInit(ToT, field.name, try self.sub_cmd.?.to(field.type, to_config));
                    },
                    .Optional => |f_opt| if (self.opts) |opts| {
                        for (opts) |opt| {
                            if (mem.eql(u8, opt.name, arg_name)) {
                                if (!opt.val.isSet() and type_info == .Struct) {
                                    if (!to_config.allow_unset) return error.ValueNotSet;
                                    @field(out, field.name) = 
                                        if (field.default_value) |def_val| @as(*field.type, @ptrCast(@alignCast(@constCast(def_val)))).*
                                        else null;
                                    break;
                                }
                                if (type_info == .Union) return @unionInit(ToT, field.name, opt.val.getAs(f_opt.child) catch continue); 
                                @field(out, field.name) = try opt.val.getAs(f_opt.child);
                            }
                        }
                    },
                    .Bool, .Int, .Float, .Pointer, .Enum => {
                        for (vals) |val| {
                            if (mem.eql(u8, val.name(), arg_name)) {
                                //if (!val.isSet() and val.argIdx() == val.maxArgs() and type_info == .Struct) {
                                if (!val.isSet() and type_info == .Struct) {
                                    if (!to_config.allow_unset) return error.ValueNotSet;
                                    const def_val = field.default_value orelse {
                                        log.err("The Field '{s}' has no default value.", .{ field.name });
                                        return error.NoDefaultValue;
                                    };
                                    @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(def_val)))).*;
                                    break;
                                }
                                if (type_info == .Union) return @unionInit(ToT, field.name, val.getAs(field.type) catch continue); 
                                @field(out, field.name) = val.getAs(field.type) catch |err| setVal: {
                                    if (!to_config.allow_incompatible) return error.IncompatibleType;
                                    break :setVal switch (field_info) {
                                        .Bool => false,
                                        .Int, .Float, => @as(field.type, 0),
                                        .Pointer => "",    
                                        else => return err,
                                    };
                                };
                            }
                        } 
                    },
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            .Optional => |a_opt| if (self.opts) |opts| {
                                for (opts) |opt| {
                                    if (mem.eql(u8, opt.name, arg_name)) {
                                        if (!opt.val.isSet() and type_info == .Struct) {
                                            if (!to_config.allow_unset) return error.ValueNotSet;
                                            @field(out, field.name) =
                                                if (field.default_value) |def_val|
                                                    @as(*field.type, @ptrCast(@alignCast(@constCast(def_val)))).*
                                                else .{ null } ** ary.len;
                                            break;
                                        }
                                        const val_tag = if (a_opt.child == []const u8) "string" else @typeName(a_opt.child);
                                        var f_ary: field.type = undefined;
                                        for (f_ary[0..], 0..) |*elm, idx| elm.* = @field(opt.val.generic, val_tag)._set_args[idx];
                                        if (type_info == .Union) return @unionInit(ToT, field.name, f_ary); 
                                        @field(out, field.name) = f_ary;
                                        break;
                                    }
                                }
                            },
                            .Bool, .Int, .Float, .Pointer => {
                                for (vals) |val| {
                                    if (mem.eql(u8, val.name(), arg_name)) {
                                        if (!val.isSet() and val.argIdx() == val.maxArgs() and type_info == .Struct) {
                                            if (!to_config.allow_unset) return error.ValueNotSet;
                                            const def_val = field.default_value orelse {
                                                log.err("The Field '{s}' has no default value.", .{ field.name });
                                                return error.NoDefaultValue;
                                            };
                                            @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(def_val)))).*;
                                            break;
                                        }
                                        const val_tag = if (ary.child == []const u8) "string" else @typeName(ary.child);
                                        var f_ary: field.type = undefined;
                                        for (f_ary[0..], 0..) |*elm, idx| elm.* = @field(val.generic, val_tag)._set_args[idx] orelse elmVal: {
                                            break :elmVal switch (ary_info) {
                                                .Bool => false,
                                                .Int, .Float, => @as(ary.child, 0),
                                                .Pointer => "",    
                                                else => if (!to_config.allow_incompatible) return error.IncompatibleType,
                                            };
                                        };
                                        if (type_info == .Union) return @unionInit(ToT, field.name, f_ary); 
                                        @field(out, field.name) = f_ary;
                                        break;
                                    }
                                } 
                            },
                            else => {
                                if (!to_config.allow_incompatible) return error.IncompatibleType;
                            },
                        }
                    },
                    else => {
                        if (!to_config.allow_incompatible) return error.IncompatibleType;
                    },
                }
            }
            return out;
        }

        /// Call this Command as the provided Function (`call_fn`), returning the provided Return Type (`ReturnT`).
        /// If the Return Type is an Error Union, this method expects only the payload Type.
        /// If the Function has a `self` parameter it can be provided using (`fn_self`). 
        /// This effectively wraps the `@call()` builtin function by using this Command's Values as the function parameters.
        pub fn callAs(self: *const @This(), comptime call_fn: anytype, fn_self: anytype, comptime ReturnT: type) !ReturnT {
            const fn_info = @typeInfo(@TypeOf(call_fn));
            const fn_name = @typeName(@TypeOf(call_fn));
            if (fn_info != .Fn) {
                log.err("Expected a Function but received '{s}'.", .{ fn_name });
                return error.ExpectedFn;
            }
            if (self.vals == null or self.vals.?.len < fn_info.Fn.params.len) {
                log.err("The provided function requires {d} parameters but only {d} was/were provided.", .{ 
                    fn_info.Fn.params.len, 
                    if (self.vals == null) 0 else self.vals.?.len });
                return error.ExpectedMoreParameters;
            }
            if (fn_info.Fn.return_type.? != ReturnT) checkErrorUnion: {
                const return_info = @typeInfo(fn_info.Fn.return_type.?);
                if (return_info == .ErrorUnion and return_info.ErrorUnion.payload == ReturnT) break :checkErrorUnion;
                log.err("The return type of '{s}' does not match the provided return type '{s}'.", .{ fn_name, @typeName(ReturnT) });
                return error.ReturnTypeMismatch;
            }

            const params = valsToParams: { 
                const param_types = comptime paramTypes: {
                    var types: [fn_info.Fn.params.len]type = undefined;
                    for (types[0..], fn_info.Fn.params) |*T, param| T.* = param.type.?;
                    break :paramTypes types;
                };
                var params_tuple: meta.Tuple(param_types[0..]) = undefined;
                const start_idx = if (@TypeOf(fn_self) == param_types[0]) 1 else 0;
                if (start_idx == 1) params_tuple[0] = fn_self;
                inline for (self.vals.?, &params_tuple, 0..) |val, *param, idx| {
                    if (idx < start_idx) continue;
                    param.* = try val.getAs(@TypeOf(param.*)); 
                }
                
                break :valsToParams params_tuple;
            };

            return @call(.auto, call_fn, params); 
        }

        /// Create Sub Commands Enum.
        /// This is useful for switching on the Sub Commands of this Command during analysis, but the Command (`self`) must be comptime-known.
        /// Prefer to use `checkSubCmd`() and `matchSubCmd`() with conditional `if` statements.
        pub fn SubCommandsEnum(comptime self: *const @This()) ?type {
            if (self.sub_cmds == null) return null; //@compileError("Could not create Sub Commands Enum. This Command has no Sub Commands.");
            var cmd_fields: [self.sub_cmds.?.len]builtin.Type.EnumField = undefined;
            for (self.sub_cmds.?, cmd_fields[0..], 0..) |cmd, *field, idx| {
                field.* = .{
                    .name = cmd.name,
                    .value = idx,
                };
            }
            return @Type(builtin.Type{
                .Enum = .{
                    .tag_type = u8,
                    .fields = cmd_fields[0..],
                    .decls = &.{},
                    .is_exhaustive = true,
                }
            });
        }

        /// Config for the Validation of this Command.
        pub const ValidateConfig = struct {
            // Check Argument Groups to ensure they exist.
            check_arg_groups: bool = true,
            // Check Command Alias Names to ensure they're distinct.
            check_cmd_aliases: bool = true,
            // Check Option Alias Names to ensure they're distinct.
            check_opt_aliases: bool = true,
            // Check for Usage/Help Commands
            check_help_cmds: bool = true,
            // Check for Usage/Help Options
            check_help_opts: bool = true,
        };

        /// Validate this Command during Comptime using the provided ValidateConfig (`valid_config`).
        /// This will check for:
        ///  - Distinct Sub Commands, Options, and Values
        ///  - Existing Argument Groups
        ///  - Distinct Command & Option Alias Names.
        pub fn validate(comptime self: *const @This(), comptime valid_config: ValidateConfig) void {
            comptime {
                @setEvalBranchQuota(100_000);
                const usage_help_strs = .{ "usage", "help" } ++ (.{ "" } ** (max_args - 2));
                // Check for distinct Sub Commands and Validate them.
                if (self.sub_cmds) |cmds| {
                    const idx_offset: u2 = if (valid_config.check_help_cmds) 2 else 0;
                    var distinct_cmd: [max_args][]const u8 =
                        if (!valid_config.check_help_cmds) .{ "" } ** max_args
                        else usage_help_strs; 
                    for (cmds, 0..) |cmd, idx| {
                        if (self.case_sensitive and utils.indexOfEql([]const u8, distinct_cmd[0..idx], cmd.name) != null) 
                            @compileError("The Sub Command '" ++ cmd.name ++ "' is set more than once.");
                        if (!self.case_sensitive and utils.indexOfEqlIgnoreCase(distinct_cmd[0..idx], cmd.name) != null) 
                            @compileError("The Sub Command '" ++ cmd.name ++ "' is set more than once.");
                        distinct_cmd[idx + idx_offset] = cmd.name;
                    }
                }

                // Check for distinct Options.
                if (self.opts) |opts| {
                    const idx_offset: u2 = if (valid_config.check_help_cmds) 2 else 0;
                    var distinct_name: [max_args][]const u8 = 
                        if (!valid_config.check_help_opts) .{ "" } ** max_args
                        else usage_help_strs; 
                    var distinct_short: [max_args]u8 = 
                        if (!valid_config.check_help_opts) .{ ' ' } ** max_args
                        else .{ 'u', 'h' } ++ (.{ ' ' } ** (max_args - 2));
                    var distinct_long: [max_args][]const u8 = 
                        if (!valid_config.check_help_opts) .{ "" } ** max_args
                        else usage_help_strs; 
                    for (opts, 0..) |opt, idx| {
                        if (utils.indexOfEql([]const u8, distinct_name[0..], opt.name) != null) 
                            @compileError("The Option '" ++ opt.name ++ "' is set more than once.");
                        distinct_name[idx + idx_offset] = opt.name;
                        if (opt.short_name != null and utils.indexOfEql(u8, distinct_short[0..], opt.short_name.?) != null) 
                            @compileError("The Option Short Name '" ++ .{ opt.short_name.? } ++ "' is set more than once.");
                        distinct_short[idx + idx_offset] = opt.short_name orelse ' ';
                        if (opt.long_name) |long_name| {
                            if (
                                (opt.case_sensitive and utils.indexOfEql([]const u8, distinct_long[0..], long_name) != null) or
                                (!opt.case_sensitive and utils.indexOfEqlIgnoreCase(distinct_long[0..], long_name) != null)
                            ) @compileError("The Option Long Name '" ++ long_name ++ "' is set more than once.");
                        }
                        distinct_long[idx + idx_offset] = opt.long_name orelse "a!garbage@long#name$";
                    }
                }

                // Check for distinct Values.
                if (self.vals) |vals| {
                    var distinct_val: [max_args][]const u8 = .{ "" } ** max_args;
                    for (vals, 0..) |val, idx| {
                        if (utils.indexOfEql([]const u8, distinct_val[0..], val.name()) != null) 
                            @compileError("The Value '" ++ val.name ++ "' is set more than once.");
                        distinct_val[idx] = val.name();
                    }
                }

                // Check for existing Argument Groups.
                if (valid_config.check_arg_groups) {
                    // - Command Groups.
                    if (self.sub_cmds) |cmds| cmdGroups: {
                        const groups = self.cmd_groups orelse break :cmdGroups;
                        checkCmds: for (cmds) |cmd| {
                            if (utils.indexOfEql([]const u8, groups, cmd.cmd_group orelse continue :checkCmds) == null)
                                @compileError("The Command '" ++ cmd.name ++ "' has non-existent Group '" ++ cmd.cmd_group.? ++ "'.\n" ++ 
                                    "This validation check can be disabled using `Command.Custom.ValidateConfig.check_arg_groups`.");
                        }
                    }
                    // - Option Groups.
                    if (self.opts) |opts| optGroups: {
                        const groups = self.opt_groups orelse break :optGroups;
                        checkCmds: for (opts) |opt| {
                            if (utils.indexOfEql([]const u8, groups, opt.opt_group orelse continue :checkCmds) == null)
                                @compileError("The Option '" ++ opt.name ++ "' has non-existent Group '" ++ opt.opt_group.? ++ "'.\n" ++
                                    "This validation check can be disabled using `Command.Custom.ValidateConfig.check_arg_groups`.");
                        }
                    }
                    // - Mandatory Option Groups.
                    if (self.mandatory_opt_groups) |man_groups| {
                        if (self.opt_groups) |groups| {
                            for (man_groups) |man_group| {
                                if (utils.indexOfEql([]const u8, groups, man_group) == null)
                                    @compileError(fmt.comptimePrint("The Mandatory Option Group {s} is not in the given Option Groups.", .{ man_group }));
                            }
                        }
                        else @compileError("Mandatory Option Groups must be a subset of Option Groups but no Option Groups were given.");
                    }
                    // - Value Groups.
                    if (self.vals) |vals| valGroups: {
                        const groups = self.val_groups orelse break :valGroups;
                        checkCmds: for (vals) |val| {
                            if (utils.indexOfEql([]const u8, groups, val.valGroup() orelse continue :checkCmds) == null)
                                @compileError("The Value '" ++ val.name() ++ "' has non-existent Group '" ++ val.valGroup.? ++ "'.\n" ++
                                    "This validation check can be disabled using `Command.Custom.ValidateConfig.check_arg_groups`.");
                        }
                    }
                }

                // Check for Distinct Command Alias Names.
                if (valid_config.check_cmd_aliases) distinctAliases: {
                    const cmds = self.sub_cmds orelse break :distinctAliases;
                    checkCmds1: for (cmds) |cmd_1| {
                        checkCmds2: for (cmds) |cmd_2| {
                            if (mem.eql(u8, cmd_1.name, cmd_2.name)) continue :checkCmds2;
                            checkAliases: for (cmd_1.alias_names orelse continue :checkCmds1) |alias| {
                                const case_sense = cmd_1.case_sensitive or cmd_2.case_sensitive; 
                                if (
                                    (case_sense and mem.eql(u8, cmd_2.name, alias)) or
                                    (!case_sense and ascii.eqlIgnoreCase(cmd_2.name, alias))
                                )
                                    @compileError(
                                        "The Command '" ++ cmd_1.name ++ "' has Alias '" ++ alias ++ "' which overshadows the Command '" ++ 
                                        cmd_2.name ++ "'.\n" ++ 
                                        "This validation check can be disabled using `Command.Custom.ValidateConfig.check_cmd_aliases`."
                                    );
                                if (
                                    (case_sense and utils.indexOfEql([]const u8, cmd_2.alias_names orelse continue :checkAliases, alias) != null) or
                                    (!case_sense and utils.indexOfEqlIgnoreCase(cmd_2.alias_names orelse continue :checkAliases, alias) != null)
                                )
                                    @compileError(
                                        "The Command '" ++ cmd_1.name ++ "' has Alias '" ++ alias ++ "' which overshadows an Alias of the Command '" ++ 
                                        cmd_2.name ++ "'.\n" ++ 
                                        "This validation check can be disabled using `Command.Custom.ValidateConfig.check_cmd_aliases`."
                                    );
                            }
                        }
                    }
                }
                // Check for Distinct Option Alias Long Names.
                if (valid_config.check_opt_aliases) distinctAliases: {
                    const opts = self.opts orelse break :distinctAliases;
                    checkCmds1: for (opts) |opt_1| {
                        const opt_1_ln = opt_1.long_name orelse {
                            if (opt_1.alias_long_names) |_| @compileError(fmt.comptimePrint("The Option {s} has aliases but no long name.", .{ opt_1.name }));
                            continue :checkCmds1;
                        };
                        checkCmds2: for (opts) |opt_2| {
                            const opt_2_ln = opt_2.long_name orelse {
                                if (opt_2.alias_long_names) |_| @compileError(fmt.comptimePrint("The Option {s} has aliases but no long name.", .{ opt_2.name }));
                                continue :checkCmds2;
                            };
                            if (mem.eql(u8, opt_1_ln, opt_2_ln)) continue :checkCmds2;
                            checkAliases: for (opt_1.alias_long_names orelse continue :checkCmds1) |alias| {
                                const case_sense = opt_1.case_sensitive or opt_2.case_sensitive; 
                                if (
                                    (case_sense and mem.eql(u8, opt_2_ln, alias)) or
                                    (!case_sense and ascii.eqlIgnoreCase(opt_2_ln, alias))
                                )
                                    @compileError(
                                        "The Option '" ++ opt_1.name ++ "' has Alias '" ++ alias ++ "' which overshadows the Option '" ++ 
                                        opt_2_ln ++ "'.\n" ++ 
                                        "This validation check can be disabled using `Command.Custom.ValidateConfig.check_opt_aliases`."
                                    );
                                if (
                                    (case_sense and utils.indexOfEql([]const u8, opt_2.alias_long_names orelse continue :checkAliases, alias) != null) or
                                    (!case_sense and utils.indexOfEqlIgnoreCase(opt_2.alias_long_names orelse continue :checkAliases, alias) != null)
                                )
                                    @compileError(
                                        "The Option '" ++ opt_1.name ++ "' has Alias '" ++ alias ++ "' which overshadows an Alias of the Option '" ++ 
                                        opt_2.name ++ "'.\n" ++ 
                                        "This validation check can be disabled using `Command.Custom.ValidateConfig.check_opt_aliases`."
                                    );
                            }
                        }
                    }
                }
            }
        }

        /// Config for the Initialization of this Command.
        pub const InitConfig = struct {
            /// Validate this Command.
            validate_cmd: bool = true,
            /// Validation Config
            valid_config: ValidateConfig = .{},
            /// Add Usage/Help message Commands to this Command.
            add_help_cmds: bool = true,
            /// Add Usage/Help message Options to this Command.
            add_help_opts: bool = true,
            /// Add Help Argument Group for Usage/Help Commands.
            /// Note, this will only take effect if `add_help_cmds` is `true`.
            add_cmd_help_group: AddHelpGroup = .AddIfOthers,
            /// Add Help Argument Group for Usage/Help Options.
            /// Note, this will only take effect if `add_help_opts` is `true`.
            add_opt_help_group: AddHelpGroup = .AddIfOthers,
            /// Help Argument Group Name.
            help_group_name: []const u8 = "HELP",
            /// Initialize this Command's Sub Commands.
            init_subcmds: bool = true,

            /// Determine behavior for adding a Help Argument Group.
            pub const AddHelpGroup = enum{
                /// Add if there are other Argument Groups.
                AddIfOthers,
                /// Add regardless of other Argument Groups.
                Add,
                /// Do not add.
                DoNotAdd,
            };
        };

        /// Initialize this Command with the provided InitConfig (`init_config`) by duplicating it with the provided Allocator (`alloc`) for Runtime use.
        /// This should be used after this Command has been created in Comptime. 
        pub fn init(comptime self: *const @This(), alloc: mem.Allocator, comptime init_config: InitConfig) !@This() {
            if (init_config.validate_cmd) {
                comptime var valid_config = init_config.valid_config;
                valid_config.check_help_cmds = init_config.add_help_cmds;
                valid_config.check_help_opts = init_config.add_help_opts;    
                self.validate(valid_config);
            }

            var init_cmd = (try alloc.dupe(@This(), &.{ self.* }))[0];

            const usage_description = fmt.comptimePrint("Show the '{s}' usage display.", .{ self.name });
            const help_description = fmt.comptimePrint("Show the '{s}' help display.", .{ self.name });

            if (init_config.add_help_cmds and (utils.indexOfEql([]const u8, &.{ "help", "usage" }, self.name) == null)) {
                const add_cmd_help_group = switch (init_config.add_cmd_help_group) {
                    .AddIfOthers => ifOthers: {
                        if (init_cmd.cmd_groups) |cmd_groups| {
                            init_cmd.cmd_groups = try mem.concat(alloc, []const u8, &.{ cmd_groups, &.{ init_config.help_group_name } });
                            break :ifOthers true;
                        }
                        break :ifOthers false;
                    },
                    .Add => add: {
                        init_cmd.cmd_groups = 
                            if (init_cmd.cmd_groups) |cmd_groups| try mem.concat(alloc, []const u8, &.{ cmd_groups, &.{ init_config.help_group_name } })
                            else try alloc.dupe([]const u8, &.{ init_config.help_group_name });
                        break :add true;
                    },
                    .DoNotAdd => false,
                };

                const help_sub_cmds = [2]@This(){
                    .{
                        .name = "usage",
                        .cmd_group = if (add_cmd_help_group) init_config.help_group_name else null, 
                        .help_prefix = init_cmd.name,
                        .description = usage_description,
                        ._alloc = alloc,
                    },
                    .{
                        .name = "help",
                        .cmd_group = if (add_cmd_help_group) init_config.help_group_name else null, 
                        .help_prefix = init_cmd.name,
                        .description = help_description,
                        ._alloc = alloc,
                    }
                };

                init_cmd.sub_cmds = 
                    if (init_cmd.sub_cmds != null) try mem.concat(alloc, @This(), &.{ init_cmd.sub_cmds.?, help_sub_cmds[0..] })
                    else try alloc.dupe(@This(), help_sub_cmds[0..]);
            }

            if (init_config.init_subcmds) addSubCmds: {
                const sub_cmds = if (self.sub_cmds) |s_cmds| s_cmds else break :addSubCmds;
                const sub_len = init_cmd.sub_cmds.?.len;
                var init_subcmds = try alloc.alloc(@This(), sub_len);
                inline for (sub_cmds, 0..) |cmd, idx| init_subcmds[idx] = try cmd.init(alloc, init_config);
                if (init_config.add_help_cmds and (utils.indexOfEql([]const u8, &.{ "help", "usage" }, self.name) == null)) {
                    init_subcmds[sub_len - 2] = init_cmd.sub_cmds.?[sub_len - 2];
                    init_subcmds[sub_len - 1] = init_cmd.sub_cmds.?[sub_len - 1];
                }
                init_cmd.sub_cmds = init_subcmds;
            }

            if (self.opts) |opts| {
                var init_opts = try alloc.alloc(@This().OptionT, opts.len);
                inline for (opts, 0..) |opt, idx| init_opts[idx] = opt.init(alloc);
                init_cmd.opts = init_opts;
            }

            if (init_config.add_help_opts) {
                const add_opt_help_group = switch (init_config.add_opt_help_group) {
                    .AddIfOthers => ifOthers: {
                        if (init_cmd.opt_groups) |opt_groups| {
                            init_cmd.opt_groups = try mem.concat(alloc, []const u8, &.{ opt_groups, &.{ init_config.help_group_name } });
                            break :ifOthers true;
                        }
                        break :ifOthers false;
                    },
                    .Add => add: {
                        init_cmd.opt_groups = 
                            if (init_cmd.opt_groups) |opt_groups| try mem.concat(alloc, []const u8, &.{ opt_groups, &.{ init_config.help_group_name } })
                            else try alloc.dupe([]const u8, &.{ init_config.help_group_name });
                        break :add true;
                    },
                    .DoNotAdd => false,
                };
                var help_opts = [2]OptionT{
                    .{
                        ._alloc = alloc,
                        .opt_group = if (add_opt_help_group) init_config.help_group_name else null, 
                        .name = "usage",
                        .short_name = 'u',
                        .long_name = "usage",
                        .description = usage_description,
                        .val = ValueT.ofType(bool, .{ .name = "usage_flag" }),
                    },
                    .{
                        ._alloc = alloc,
                        .opt_group = if (add_opt_help_group) init_config.help_group_name else null, 
                        .name = "help",
                        .short_name = 'h',
                        .long_name = "help",
                        .description = help_description,
                        .val = ValueT.ofType(bool, .{ .name = "help_flag" }),
                    },
                };
                for (help_opts[0..]) |*opt| opt.* = opt.init(alloc);

                init_cmd.opts = 
                    if (init_cmd.opts) |init_opts| try mem.concat(alloc, @This().OptionT, &.{ init_opts, help_opts[0..] })
                    else try alloc.dupe(OptionT, help_opts[0..]);
            }

            if (self.vals) |vals| {
                var init_vals = try alloc.alloc(@This().ValueT, vals.len);
                inline for (vals, 0..) |val, idx| init_vals[idx] = val.init(alloc);
                init_cmd.vals = init_vals;
            }

            init_cmd._alloc = alloc;

            return init_cmd; 
        }

        /// De-initialize this Command with its original Allocator.
        /// If this Command has not yet been initialized, this does nothing.
        pub fn deinit(self: *const @This()) void {
            const alloc = self._alloc orelse return;
            if (self.opts) |opts| alloc.free(opts); 
            if (self.vals) |vals| alloc.free(vals); 
            if (self.sub_cmds) |sub_cmds|
                for (sub_cmds) |*cmd| cmd.deinit();
            self._alloc.?.destroy(self);
        }
    };
}

