using SweetEditor;

namespace Demo {
	partial class Form1 {
		private System.ComponentModel.IContainer components = null;

		protected override void Dispose(bool disposing) {
			if (disposing && (components != null)) {
				components.Dispose();
			}
			base.Dispose(disposing);
		}

		#region Windows Form Designer generated code

		private void InitializeComponent() {
			components = new System.ComponentModel.Container();
			editorControl1 = new SweetEditorControl(components);
			SuspendLayout();
			// 
			// editorControl1
			// 
			editorControl1.Font = new Font("Consolas", 11F);
			editorControl1.Location = new Point(0, 40);
			editorControl1.Name = "editorControl1";
			editorControl1.Size = new Size(1831, 1135);
			editorControl1.TabIndex = 0;
			// 
			// Form1
			// 
			AutoScaleDimensions = new SizeF(11F, 24F);
			AutoScaleMode = AutoScaleMode.Font;
			ClientSize = new Size(1831, 1175);
			Controls.Add(editorControl1);
			Name = "Form1";
			Text = "SweetEditor Demo";
			ResumeLayout(false);
		}

		#endregion

		private SweetEditorControl editorControl1;
	}
}
