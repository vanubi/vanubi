/*
 *  Copyright © 2011-2013 Luca Bruno
 *
 *  This file is part of Vanubi.
 *
 *  Vanubi is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Vanubi is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Vanubi.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Vanubi {
	public delegate G TaskFunc<G> (Cancellable cancellable) throws Error;

	public async G run_in_thread<G> (owned TaskFunc<G> func, Cancellable cancellable) throws Error {
		SourceFunc resume = run_in_thread.callback;
		Error err = null;
		G result = null;
		new Thread<void*> (null, () => {
				try {
					result = func (cancellable);
				} catch (Error e) {
					err = e;
				}
				Idle.add ((owned) resume);
				return null;
			});
		yield;
		if (err != null) {
			throw err;
		}
		cancellable.set_error_if_cancelled ();
		return result;
	}
}
