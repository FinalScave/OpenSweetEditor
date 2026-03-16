using System.Reflection;
using System.Runtime.InteropServices;

namespace Demo {
	internal static class Program {

		[STAThread]
		static void Main() {
			ApplicationConfiguration.Initialize();
			Application.Run(new Form1());
		}
	}
}