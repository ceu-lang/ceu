local cc = CEU.opts.cc_exe..' '..CEU.opts.cc_input..' '..
            '-o '..CEU.opts.cc_output..' '..
            CEU.opts.cc_args
os.execute(cc)
