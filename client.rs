extern crate byteorder;
extern crate subprocess;

use byteorder::{BigEndian, ReadBytesExt, WriteBytesExt};
use subprocess::{Popen, PopenConfig, PopenError, Redirection};
use std::ffi::OsString;
use std::io::{Cursor, Error, Read, Write};
use std::result::Result;

pub struct Client {
    server: Popen,
    encoding: String,
}

#[derive(Debug)]
pub enum HglibError {
    Popen(subprocess::Popen),
    Str(String),
}

impl From<PopenError> for HglibError {
    fn from(err: PopenError) -> HglibError {
        HglibError::Str(format!("Hglib error: {}", err))
    }
}

impl From<Error> for HglibError {
    fn from(err: Error) -> HglibError {
        HglibError::Str(format!("Hglib error: {}", err))
    }
}

impl From<std::str::Utf8Error> for HglibError {
    fn from(err: std::str::Utf8Error) -> HglibError {
        HglibError::Str(format!("Hglib error: {}", err))
    }
}

impl From<std::string::FromUtf8Error> for HglibError {
    fn from(err: std::string::FromUtf8Error) -> HglibError {
        HglibError::Str(format!("Hglib error: {}", err))
    }
}

impl Drop for Client {
    fn drop(&mut self) {
        self.close().unwrap();
    }
}

impl Client {
    
    pub fn open(path: &str, encoding: &str) -> Result<Client, HglibError> {
        let mut env: Vec<(OsString, OsString)> = vec![(OsString::from("HGPLAIN"), OsString::from("1"))];
        if !encoding.is_empty() {
            env.push((OsString::from("HGENCODING"), OsString::from(encoding)));
        }
        let mut server = Popen::create(&["hg",
                                         "serve",
                                         "--cmdserver", "pipe",
                                         "-R", path],
                                       PopenConfig {
                                           stdout: Redirection::Pipe,
                                           stdin: Redirection::Pipe,
                                           stderr: Redirection::Pipe,
                                           env: Some(env),
                                           cwd: Some(OsString::from(path)),
                                           ..Default::default()
                                       })?;
        let encoding = Client::readhello(&mut server)?;
        let client = Client {
            server,
            encoding,
        };
        Ok(client)
    }

    pub fn close(&mut self) -> Result<(), HglibError> {
        self.server.terminate()?;
        Ok(())
    }

    pub fn runcommand(&mut self, args: &Vec<&str>) -> Result<(Vec<u8>, i32), HglibError> {
        /* Write the data on stdin:
           runcommand\n
           len(arg0\0arg1\0arg2...)
           arg0\0arg1\0arg2... */
        let mut stdin = self.server.stdin.as_mut().unwrap();
        let args_size: usize = args.into_iter().map(|arg| -> usize { arg.len() }).sum();
        let size = args_size + args.len() - 1;
        writeln!(&mut stdin, "runcommand")?;
        stdin.write_u32::<BigEndian>(size as u32)?;
        if let Some((first, args)) = args.split_first() {
            write!(&mut stdin, "{}", first)?;
            for arg in args {
                write!(&mut stdin, "\0{}", arg)?;
            }
        }
        stdin.flush()?;

        /* Read the data on stdout:
           o{u32 = len}{data}
           ...
           r{u32} */
        let stdout = self.server.stdout.as_mut().unwrap();
        let mut out = Vec::<u8>::with_capacity(4096);
        let mut chan: Vec<u8> = vec![0; 1];
        let mut returned_err: Option<Result<(Vec<u8>, i32), HglibError>> = None;
        loop {
            let n = stdout.read(&mut chan)?;
            if n != 1 {
                return Err(HglibError::Str("Hglib error: empty stdout.".to_string()));
            }
            let len = stdout.read_u32::<BigEndian>()? as usize;
            match chan[0] {
                b'e' => {
                    // We've an error
                    let mut err: Vec<u8> = vec![0; len];
                    stdout.read(&mut err)?;
                    let err = std::str::from_utf8(&err)?;
                    returned_err = Some(Err(HglibError::Str(format!("Hglib error: {}", err))));
                }
                b'o' => {
                    let mut pos = out.len();
                    out.resize(pos + len, 0);
                    let mut to_read = len;
                    loop {
                        let n = stdout.read(&mut out[pos..])?;
                        if n == to_read {
                            break;
                        }
                        to_read -= n;
                        pos += n;
                    }
                }
                b'r' => {
                    let mut code: Vec<u8> = vec![0; len];
                    stdout.read(&mut code)?;
                    let mut cur = Cursor::new(&code);
                    let code = cur.read_i32::<BigEndian>()?;
                    if let Some(err) = returned_err {
                        return err;
                    }
                    return Ok((out, code));
                }
                _ => {
                    return Err(HglibError::Str(format!("Hglib error: invalid channel {}", chan[0] as char)));
                }
            }
        }
    }

    fn readhello(server: &mut Popen) -> Result<String, HglibError> {
        let stdout = server.stdout.as_mut().unwrap();
        let mut chan: Vec<u8> = vec![0; 1];
        let n = stdout.read(&mut chan)?;
        if n != 1 || chan[0] != b'o' {
            return Err(HglibError::Str("Hglib error: cannot read hello.".to_string()))
        }

        let len = stdout.read_u32::<BigEndian>()? as usize;
        let mut data: Vec<u8> = vec![0; len];

        let n = stdout.read(&mut data)?;
        if n != len {
            return Err(HglibError::Str("Hglib error: cannot read hello (invalid length)".to_string()))
        }

        let out = std::str::from_utf8(&data)?;
        let out: Vec<&str> = out.split('\n').collect();

        assert!(out[0].contains("capabilities: "));
        assert!(out[1].contains("encoding: "));

        Ok(out[1]["encoding: ".len()..].to_string())
    }
}
